import Option "mo:base/Option";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import T "../../../Types/Types.All";
import Account "../Account/Account";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Utils "../Utils/Utils";
import MemoryController "../../../Modules/Token/MemoryController/MemoryController";
import Converters "../../../Modules/Converters/Converters";
import TransferHelper "../../../Modules/Token/Transfer/Transfer";
import CommonTypes "../../../Types/Types.Common";
import ICRC1 "ICRC1.Implementation";

/// The ICRC2 methods implementation
module {

    private type TokenData = T.TokenTypes.TokenData;
    private type Balance = CommonTypes.Balance;

    public func icrc2_approve(
        caller : Principal,
        args : T.TransactionTypes.ApproveArgs,
        token : TokenData,
        memoryController : MemoryController.MemoryController,
    ) : T.TransactionTypes.ApproveResult {

        let app_req = Converters.create_approve_req(args, caller);

        // check if caller has enough token amount for the approval fee
        switch (validate_approved_request(token, memoryController, app_req)) {
            case (#err(errorType)) {
                return #Err(errorType);
            };
            case (#ok(_)) {};
        };

        // Is owner is Fee-whitelisted then zero fee will be used for the approval
        let real_fee_to_use : Balance = Utils.get_real_token_fee_with_specified_defaultFee(
            app_req.from.owner,
            app_req.from.owner,
            token,
            app_req.fee,
        );

        if (real_fee_to_use > 0) {
            // burn fee
            Utils.burn_balance(token, app_req.encoded.from, real_fee_to_use);
        };

        return memoryController.databaseController.write_approval(app_req);
    };

    public func icrc2_allowance(
        allowanceArgs : T.TransactionTypes.AllowanceArgs,
        memoryController : MemoryController.MemoryController,
    ) : T.TransactionTypes.Allowance {

        memoryController.databaseController.get_allowance(allowanceArgs.account, allowanceArgs.spender);
    };

    public func icrc2_transfer_from(
        caller : Principal,
        args : T.TransactionTypes.TransferFromArgs,
        token : TokenData,
        memoryController : MemoryController.MemoryController,
    ) : async* T.TransactionTypes.TransferFromResponse {

        let tx_kind : T.TransactionTypes.TxKind = if (args.from == token.minting_account) {
            #mint;
        } else if (args.to == token.minting_account) {
            #burn;
        } else {
            #transfer;
        };

        let tx_request : T.TransactionTypes.TransactionFromRequest = Converters.create_transfer_from_req(args, caller, token, tx_kind);

        let validationResult = validate_transferFrom_request(token, tx_request, memoryController);
        switch (validationResult) {
            case (#err(errorType)) {
                return #Err(errorType);
            };
            case (#ok(_)) {};
        };

        // If from or to is Fee-Whitelisted then 0 fee will be used
        let real_fee_to_use : Balance = Utils.get_real_token_fee_with_specified_defaultFee(
            tx_request.from.owner,
            tx_request.to.owner,
            token,
            tx_request.fee,
        );

        // Reduce the allowance-amount
        let reduceAmount : Nat = Nat.max(tx_request.amount + real_fee_to_use, 0);

        let spender : T.AccountTypes.Account = {
            owner = caller;
            subaccount = args.spender_subaccount;
        };
        memoryController.databaseController.reduce_allowance_amount(tx_request.from, spender, reduceAmount);

        // process transaction
        switch (tx_request.kind) {
            case (#mint) {
                Utils.mint_balance(token, tx_request.encoded.to, tx_request.amount);
            };
            case (#burn) {
                Utils.burn_balance(token, tx_request.encoded.from, tx_request.amount);
            };
            case (#transfer) {
                Utils.transfer_balance(token, { tx_request with fee = real_fee_to_use });

                if (real_fee_to_use > 0) {
                    // burn fee
                    Utils.burn_balance(token, tx_request.encoded.from, real_fee_to_use);
                };

            };
        };

        let transactionRequest : T.TransactionTypes.TransactionRequest = {
            tx_request with fee = real_fee_to_use
        };
        // store the transaction
        let tx_index : Nat = await* ICRC1.store_transaction(
            token,
            transactionRequest,
            memoryController.model.settings.archive_canisterIds,
            memoryController.model
        );

        return #Ok(tx_index);
    };

    /// Checks if a Transfer From request is valid
    public func validate_transferFrom_request(
        token : TokenData,
        txf_req : T.TransactionTypes.TransactionFromRequest,
        memoryController : MemoryController.MemoryController,
    ) : Result.Result<(), T.TransactionTypes.TransferFromError> {

        let { allowance; expires_at } = memoryController.databaseController.get_allowance(txf_req.from, txf_req.spender);
        
        let real_fee_to_be_used : Balance = Utils.get_real_token_fee_with_specified_defaultFee(
            txf_req.from.owner,
            txf_req.spender.owner,
            token,
            txf_req.fee,
        );

        if (allowance < txf_req.amount + real_fee_to_be_used) {
            return #err(
                #InsufficientAllowance({
                    allowance = allowance;
                })
            );
        };
        if (not validate_expiration(token, expires_at)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Allowance has already expired";
                })
            );
        };

        let txReqForValidation : T.TransactionTypes.TransactionRequest = {
            txf_req with fee = real_fee_to_be_used
        };

        switch (TransferHelper.validate_request(token, txReqForValidation, txf_req.fee)) {
            case (#err(errorType)) {
                return #err(errorType);
            };
            case (#ok(_)) {};
        };

        return #ok();
    };

    /// Checks if an approve request is valid
    private func validate_approved_request(
        token : TokenData,
        memoryController : MemoryController.MemoryController,
        app_req : T.TransactionTypes.ApproveRequest,
    ) : Result.Result<(), T.TransactionTypes.ApproveError> {

        if (app_req.from.owner == app_req.spender.owner) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "The spender account owner cannot be equal to the source account owner.";
                })
            );
        };

        if (not Account.validate(app_req.from)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for approval source. " # debug_show (app_req.from);
                })
            );
        };

        if (not Account.validate(app_req.spender)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for approval spender. " # debug_show (app_req.spender);
                })
            );
        };

        // TODO: Verify if approval memo should be validated for approvals.
        if (not TransferHelper.validate_memo(app_req.memo)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes";
                })
            );
        };

        // TODO: Verify if approval fee should be validated as a transfer fee.
        if (not TransferHelper.validate_fee(token, app_req.fee)) {
            return #err(
                #BadFee {
                    expected_fee = token.defaultFee;
                }
            );
        };

        let balance : T.Balance = Utils.get_balance(
            token.accounts,
            app_req.encoded.from,
        );

        // Is owner is Fee-whitelisted then 0 fee will be used for the approval
        let real_fee_to_use : Balance = Utils.get_real_token_fee_with_specified_defaultFee(
            app_req.from.owner,
            app_req.from.owner,
            token,
            app_req.fee,
        );

        // If no approval fee provided, validates against transaction fee.
        if (Option.get(app_req.fee, real_fee_to_use) > balance) {
            return #err(#InsufficientFunds { balance });
        };

        // Validates that the approval contains the expected allowance

        switch (app_req.expected_allowance) {
            case null {};
            case (?expected) {

                let allowance_record = memoryController.databaseController.get_allowance(app_req.from, app_req.spender);

                if (expected != allowance_record.allowance) {
                    return #err(
                        #AllowanceChanged {
                            current_allowance = allowance_record.allowance;
                        }
                    );
                };
            };
        };

        if (not validate_expiration(token, app_req.expires_at)) {
            return #err(
                #Expired {
                    ledger_time = Nat64.fromNat(Int.abs(Time.now()));
                }
            );
        };

        switch (app_req.created_at_time) {
            case (null) {};
            case (?created_at_time) {

                if (TransferHelper.is_too_old(token, created_at_time)) {
                    return #err(#TooOld);
                };

                if (TransferHelper.is_in_future(token, created_at_time)) {
                    return #err(
                        #CreatedInFuture {
                            ledger_time = Nat64.fromNat(Int.abs(Time.now()));
                        }
                    );
                };
            };
        };

        #ok();
    };

    // Checks if an approval expiration is greater than the current ledger time
    public func validate_expiration(token : TokenData, expires_at : ?Nat64) : Bool {
        switch (expires_at) {
            case null { return true };
            case (?expiration) {
                return TransferHelper.is_in_future(token, expiration);
            };
        };
    };

};
