import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";
import Account "Account/Account";
import Trie "mo:base/Trie";
import Utils "Utils/Utils";
import Transfer "Transfer/Transfer";
import T "../../Types/Types.All";
import ArchiveHelper "Archive/ArchiveHelper";

module {
    let { SB } = Utils;

    private type Balance = T.Balance;
    private type Account = T.AccountTypes.Account;
    private type Subaccount = T.AccountTypes.Subaccount;
    private type AccountBalances = T.AccountTypes.AccountBalances;
    private type TransferArgs = T.TransactionTypes.TransferArgs;
    private type TransferResult = T.TransactionTypes.TransferResult;
    private type SupportedStandard = T.TokenTypes.SupportedStandard;
    private type TokenData = T.TokenTypes.TokenData;
    private type MetaDatum = T.TokenTypes.MetaDatum;

    /// Retrieve the name of the token
    public func icrc1_name(token : TokenData) : Text {
        token.name;
    };

    /// Retrieve the symbol of the token
    public func icrc1_symbol(token : TokenData) : Text {
        token.symbol;
    };

    /// Retrieve the number of decimals specified for the token
    public func icrc1_decimals(token : TokenData) : Nat8 {
        token.decimals;
    };

    /// Retrieve the fee for each transfer
    public func icrc1_fee(token : TokenData) : Balance {
        token.defaultFee;
    };

    /// Retrieve all the metadata of the token
    public func icrc1_metadata(token : TokenData) : [MetaDatum] {
        [
            ("icrc1:fee", #Nat(token.defaultFee)),
            ("icrc1:name", #Text(token.name)),
            ("icrc1:symbol", #Text(token.symbol)),
            ("icrc1:decimals", #Nat(Nat8.toNat(token.decimals))),
            ("icrc1:minting_allowed", #Text(debug_show (token.minting_allowed))),
            ("icrc1:logo", #Text(token.logo)),
        ];
    };

    /// Returns the total supply of circulating tokens
    public func icrc1_total_supply(token : TokenData) : Balance {
        var iter = Trie.iter(token.accounts.trie);
        var totalBalances : Nat = 0;

        //TODO: Maybe use variables for this, and do not iterate all balances.
        for ((k : Blob, v : T.CommonTypes.Balance) in iter) {
            totalBalances := totalBalances + v;
        };

        return totalBalances;
    };

    /// Returns the account with the permission to mint tokens
    ///
    /// Note: **The minting account can only participate in minting
    /// and burning transactions, so any tokens sent to it will be
    /// considered burned.**

    public func icrc1_minting_account(token : TokenData) : Account {
        token.minting_account;
    };

    /// Retrieve the balance of a given account
    public func icrc1_balance_of({ accounts } : TokenData, account : Account) : Balance {
        let encoded_account = Account.encode(account);
        Utils.get_balance(accounts, encoded_account);
    };

    /// Transfers tokens from one account to another account (minting and burning included)
    public func icrc1_transfer(
        token : TokenData,
        args : TransferArgs,
        caller : Principal,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
    ) : async* TransferResult {

        let from = {
            owner = caller;
            subaccount = args.from_subaccount;
        };

        let tx_kind : T.TransactionTypes.TxKind = if (from == token.minting_account) {

            if (token.minting_allowed == false) {
                return #Err(#GenericError { error_code = 401; message = "Error: Minting not allowed for this token." });
            };

            if (caller != token.minting_account.owner) {
                return #Err(
                    #GenericError {
                        error_code = 401;
                        message = "Unauthorized: Minting not allowed.";
                    }
                );
            };

            #mint;
        } else if (args.to == token.minting_account) {
            #burn;
        } else {
            #transfer;
        };

        let feeFromRequest = args.fee;
        let tx_req : T.TransactionTypes.TransactionRequest = Utils.create_transfer_req(args, caller, tx_kind, token);

        switch (Transfer.validate_request(token, tx_req, feeFromRequest)) {
            case (#err(errorType)) {
                return #Err(errorType);
            };
            case (#ok(_)) {};
        };

        let { encoded; amount } = tx_req;

        // process transaction
        switch (tx_req.kind) {
            case (#mint) {
                Utils.mint_balance(token, encoded.to, amount);
            };
            case (#burn) {
                Utils.burn_balance(token, encoded.from, amount);
            };
            case (#transfer) {

                Utils.transfer_balance(token, tx_req);

                // burn fee
                Utils.burn_balance(token, encoded.from, tx_req.fee);
            };
        };

        // store transaction
        let tx_index : Nat = await* store_transaction(token, tx_req, archive_canisterIds);

        #Ok(tx_index);
    };

    public func store_transaction(
        token : TokenData,
        tx_req : T.TransactionTypes.TransactionRequest,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
    ) : async* Nat {

        // store transaction
        let index = SB.size(token.transactions) + token.archive.stored_txs;
        let tx = Utils.req_to_tx(tx_req, index);
        SB.add(token.transactions, tx);

        // transfer transaction to archive if necessary
        let result : (Bool, ?Principal) = await* ArchiveHelper.append_transactions_into_archive_if_needed(token);
        if (result.0 == true) {
            switch (result.1) {
                case (?principal) ignore ArchiveHelper.updateCanisterIdList(principal, archive_canisterIds);
                case (null) {};
            };
        };

        return tx.index;
    };

    /// Returns an array of standards supported by this token
    public func icrc1_supported_standards(token : TokenData) : [SupportedStandard] {
        SB.toArray(token.supported_standards);
    };

};
