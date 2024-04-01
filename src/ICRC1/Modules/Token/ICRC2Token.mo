import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import SB "mo:StableBuffer/StableBuffer";
import ICRC1 "ICRC1Token";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Itertools "mo:itertools/Iter";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import T "../../Types/Types.All";
import Constants "../../Types/Types.Constants";
import Account "Account/Account";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Utils "Utils/Utils";
import Model "../../Types/Types.Model";
import HashList "mo:memory-hashlist";
import MemoryController "../../Modules/Token/MemoryController/MemoryController";
import Converters "../../Modules/Converters/Converters";
import TransferHelper "../../Modules/Token/Transfer/Transfer";
import CommonTypes "../../Types/Types.Common";

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
        switch (validate_request(token,memoryController, app_req)) {
            case (#err(errorType)) {
                return #Err(errorType);
            };
            case (#ok(_)) {};
        };

        // Is owner is Fee-whitelisted then zero fee will be used for the approval
        let real_fee_to_use : Balance = Utils.get_real_token_fee(
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
        memoryController : MemoryController.MemoryController
    ) : T.TransactionTypes.Allowance {

        memoryController.databaseController.get_allowance(allowanceArgs.account, allowanceArgs.spender);
    };

    public func icrc2_transfer_from(
        caller : Principal,
        transferFromArgs : T.TransactionTypes.TransferFromArgs,
        token : TokenData,
    ) : async T.TransactionTypes.TransferFromResponse {

        return #Ok(0);
    };

    // private func create_approve_req(
    //     args : T.TransactionTypes.ApproveArgs,
    //     owner : Principal,
    //     tx_kind : T.TransactionTypes.OperationKind,
    // ) : T.ApproveTxRequest {

    //     let from = {
    //         owner;
    //         subaccount = args.from_subaccount;
    //     };

    //     let to = {
    //         owner = args.spender;
    //         subaccount = null;
    //     };

    //     let encoded = {
    //         from = Account.encode(from);
    //         to = Account.encode(to);
    //     };

    //     {
    //         kind = tx_kind;
    //         from = from;
    //         spender = to;
    //         amount = args.amount;
    //         expires_at = args.expires_at;
    //         fee = args.fee;
    //         memo = args.memo;
    //         created_at_time = args.created_at_time;
    //         expected_allowance = args.expected_allowance;
    //         // args with kind = #approve;
    //         encoded;
    //     };
    // };

    /// Checks if an approve request is valid
    private func validate_request(
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
        let real_fee_to_use : Balance = Utils.get_real_token_fee(
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

                let allowance_record_or_null = memoryController.databaseController.get_allowance(app_req.encoded.from, app_req.encoded.spender);

                switch (allowance_record_or_null) {
                    case (?allowance_record) {
                        if (expected != allowance_record.amount) {
                            return #err(
                                #AllowanceChanged {
                                    current_allowance = allowance_record.amount;
                                }
                            );
                        };

                    };
                    case null {
                        // do nothing
                    };
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
