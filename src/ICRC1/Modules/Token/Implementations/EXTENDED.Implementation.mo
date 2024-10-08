import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Bool "mo:base/Bool";
import Utils "../Utils/Utils";
import T "../../../Types/Types.All";
import { ConstantTypes } = "../../../Types/Types.All";
import ICRC1 "ICRC1.Implementation";
import Model "../../../Types/Types.Model";
import MemoryController "../../../Modules/Token/MemoryController/MemoryController";
import TypesBackupRestore "../../../Types/Types.BackupRestore";
import BackupService "../BackupRestore/BackupService";
import Account "../Account/Account";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Int "mo:base/Int";

/// Additional Token implementations
///() ==Additional methods that are not defined in ICRC1 or ICRC2)
module {

    let { SB } = Utils;
    private type AccountType = T.AccountTypes.Account;
    private type TokenData = T.TokenTypes.TokenData;
    private type Balance = T.Balance;
    private type SetTextParameterResult = T.TokenTypes.SetTextParameterResult;
    private type SetBalanceParameterResult = T.TokenTypes.SetBalanceParameterResult;
    private type SetNat8ParameterResult = T.TokenTypes.SetNat8ParameterResult;
    private type ArchiveInterface = T.ArchiveTypes.ArchiveInterface;
    private type Mint = T.TransactionTypes.Mint;
    private type TransferResult = T.TransactionTypes.TransferResult;
    private type BurnArgs = T.TransactionTypes.BurnArgs;
    private type TxIndex = T.TransactionTypes.TxIndex;
    private type Transaction = T.TransactionTypes.Transaction;
    private type GetTransactionsRequest = T.TransactionTypes.GetTransactionsRequest;
    private type GetTransactionsResponse = T.TransactionTypes.GetTransactionsResponse;
    private type QueryArchiveFn = T.TransactionTypes.QueryArchiveFn;
    private type TransactionRange = T.TransactionTypes.TransactionRange;
    private type ArchivedTransaction = T.TransactionTypes.ArchivedTransaction;
    private type TransferArgs = T.TransactionTypes.TransferArgs;

    /// Retrieve the minimum burn amount for the token
    public func min_burn_amount(token : TokenData) : Balance {
        token.min_burn_amount;
    };

    /// Returns the current archive canister
    public func get_archive(token : TokenData) : ArchiveInterface {
        token.archive.canister;
    };

    /// Returns the total number of transactions in the archive
    public func get_archive_stored_txs(token : TokenData) : Nat {
        token.archive.stored_txs;
    };

    /// Returns the total supply of minted tokens
    public func minted_supply(token : TokenData) : Balance {
        token.minted_tokens;
    };

    /// Returns the total supply of burned tokens
    public func burned_supply(token : TokenData) : Balance {
        token.burned_tokens;
    };

    /// Returns the maximum supply of tokens
    public func max_supply(token : TokenData) : Balance {
        token.max_supply;
    };

    /// Helper function to mint tokens with minimum args
    public func mint(
        token : TokenData,
        args : Mint,
        caller : Principal,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
        model : Model.Model,
    ) : async* TransferResult {

        if (token.minting_allowed == false) {
            return #Err(#GenericError { error_code = 401; message = "Error: Minting not allowed for this token." });
        };
        if (caller == token.minting_account.owner) {
            let transfer_args : TransferArgs = {
                args with from = token.minting_account;
                from_subaccount = null;
                fee = null;
            };

            await* ICRC1.icrc1_transfer(token, transfer_args, caller, archive_canisterIds, model);

        } else {
            return #Err(#GenericError { error_code = 401; message = "Unauthorized: Minting not allowed." });
        };
    };

    /// Helper function to burn tokens with minimum args
    public func burn(
        token : TokenData,
        args : BurnArgs,
        caller : Principal,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
        model : Model.Model,
    ) : async* TransferResult {

        let transfer_args : TransferArgs = {
            args with to = token.minting_account;
            fee = null;
        };

        await* ICRC1.icrc1_transfer(token, transfer_args, caller, archive_canisterIds, model);
    };

    /// Returns the total number of transactions that have been processed by the given token.
    public func total_transactions(token : TokenData) : Nat {
        let { archive; transactions } = token;
        archive.stored_txs + SB.size(transactions);
    };

    /// Retrieves the transaction specified by the given `tx_index`
    public func get_transaction(token : TokenData, tx_index : TxIndex) : async* ?Transaction {
        let { archive; transactions } = token;

        if (tx_index < archive.stored_txs) {
            await archive.canister.get_transaction(tx_index);
        } else {
            let local_tx_index = (tx_index - archive.stored_txs) : Nat;
            SB.getOpt(transactions, local_tx_index);
        };
    };

    public func get_transactions_by_index_directly(token : TokenData, start : Nat, length : Nat) : async* [Transaction] {

        let { archive; transactions } = token;
        if (length <= 0) {
            return [];
        };

        var lengthToUse = Nat.min(length, ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST);
        let totalNumberOfTransactions = total_transactions(token);
        if (start >= totalNumberOfTransactions) {
            return [];
        };

        let localTransactionsCount = SB.size(transactions);

        let txBuffer = Buffer.Buffer<Transaction>(lengthToUse);
        var firstIndexInCacheOrNull : ?Nat = null;
        
        if (localTransactionsCount > 0) {

            let firstCachedTxOrNull : ?Transaction = SB.getOpt(transactions, 0);
            var firstTx:Nat = 0;
            var found:Bool = false;
            switch (firstCachedTxOrNull) {
                case (?firstCachedTx) {
                    firstIndexInCacheOrNull := Option.make(firstCachedTx.index);
                    found := true;
                    firstTx := firstCachedTx.index;
                };
                case (_) {
                    // do nothing
                };
            };
          
                     
            let maxTxToFind = start + lengthToUse;
            if (found == true and maxTxToFind >= firstTx) {
              
                var startTx=0;
                if (start > firstTx) {
                    startTx := start - firstTx;
                };
                
                label internLoop for (index in Iter.range(startTx, localTransactionsCount)) {

                    let cachedTxOrNull : ?Transaction = SB.getOpt(transactions, index);
                    switch (cachedTxOrNull) {
                        case (?cachedTx) {
                            let txIndex : Nat = cachedTx.index;
                            if (txIndex > maxTxToFind) {
                                break internLoop;
                            };
                            
                            if (txIndex >= start and txIndex < maxTxToFind) {                            
                                txBuffer.insert(0, cachedTx);
                            } else {
                                break internLoop;
                            };
                        };
                        case (_) {
                            break internLoop;
                        };

                    };
                };
            };
        };

        let bufferSize = txBuffer.size();      
        let missingCount = (lengthToUse - bufferSize) : Nat;
        
        if (missingCount > 0 and archive.stored_txs > 0) {

            var archiveMustBeCalled : Bool = false;
          
            switch (firstIndexInCacheOrNull) {
                case (?firstIndexInCache) {
                    if (start < firstIndexInCache) {
                        archiveMustBeCalled := true;
                    };
                };
                case (_) {
                    // do nothing
                    archiveMustBeCalled := true;
                };
            };
           
            if (archiveMustBeCalled == true) {
                let getTransactionRequest : GetTransactionsRequest = {
                    start = start;
                    length = missingCount;
                };
           
                let archivedTransactions = await archive.canister.get_transactions(getTransactionRequest);
                if (Array.size(archivedTransactions.transactions) > 0) {
                    let txFromArchive = Buffer.fromArray<Transaction>(
                        Array.reverse<Transaction>(archivedTransactions.transactions)
                    );

                    txBuffer.append(txFromArchive);
                };
            };
        };

        return txBuffer.toArray();
    };

    public func get_transactions_by_principal(token : TokenData, principal : Principal, startIndex : Nat, length : Nat) : async* [T.TransactionTypes.Transaction] {

        if (length <= 0) {
            return [];
        };

        let countResult = await* get_transactions_by_principal_count_internal(token, principal);

        let countCached : Nat = countResult.0;
        let countInArchiveFound : Nat = countResult.1;

        let totalFound = countCached + countInArchiveFound;
        if (totalFound <= 0 or startIndex >= totalFound) {
            return [];
        };

        let lengthToUse : Nat = Nat.min(length, ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST);

        let result = Buffer.Buffer<Transaction>(lengthToUse);

        let { archive; transactions } = token;

        if (startIndex < countInArchiveFound) {
            let txFoundInArchive = await archive.canister.get_transactions_by_principal(principal, startIndex, lengthToUse);
            if (Array.size(txFoundInArchive) > 0) {
                result.append(Buffer.fromArray<Transaction>(txFoundInArchive));
            };
        };

        var missingTxCount : Nat = Nat.max((lengthToUse - result.size()), 0);
        if (missingTxCount > 0) {

            let localTransactionsCount = SB.size(transactions);

            for (index in Iter.range(0, localTransactionsCount)) {

                let cachedTxOrNull : ?Transaction = SB.getOpt(transactions, index);
                switch (cachedTxOrNull) {
                    case (?cachedTx) {
                        if (transaction_contains_principal(cachedTx, principal) == true) {
                            // we want to have the reverse order
                            result.insert(0, cachedTx);
                        };

                    };
                    case (_) {
                        // do nothing
                    };

                };
            };
        };

        return Buffer.toArray(result);
    };

    public func get_transactions_by_principal_count(token : TokenData, principal : Principal) : async* Nat {

        let foundTransactions = await* get_transactions_by_principal_count_internal(token, principal);

        let totalFound = foundTransactions.0 + foundTransactions.1;
        return totalFound;
    };

    /// Retrieves the transactions specified by the given range
    public func get_transactions(token : TokenData, req : GetTransactionsRequest) : GetTransactionsResponse {
        let { archive; transactions } = token;

        var first_index = 0xFFFF_FFFF_FFFF_FFFF; // returned if no transactions are found

        let req_end = req.start + req.length;
        let tx_end = archive.stored_txs + SB.size(transactions);

        var txs_in_canister : [Transaction] = [];

        if (req.start < tx_end and req_end >= archive.stored_txs) {
            first_index := Nat.max(req.start, archive.stored_txs);
            let tx_start_index = (first_index - archive.stored_txs) : Nat;

            txs_in_canister := SB.slice(transactions, tx_start_index, tx_start_index + req.length);
        };

        let archived_range = if (req.start < archive.stored_txs) {
            {
                start = req.start;
                end = Nat.min(
                    archive.stored_txs,
                    (req.start + req.length) : Nat,
                );
            };
        } else {
            { start = 0; end = 0 };
        };

        let txs_in_archive = (archived_range.end - archived_range.start) : Nat;

        let size = Utils.div_ceil(txs_in_archive, ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST);

        let archived_transactions = Array.tabulate(
            size,
            func(i : Nat) : ArchivedTransaction {
                let offset = i * ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST;
                let start = offset + archived_range.start;
                let length = Nat.min(
                    ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST,
                    archived_range.end - start,
                );

                let callback = token.archive.canister.get_transactions;

                { start; length; callback };
            },
        );

        {
            log_length = txs_in_archive + txs_in_canister.size();
            first_index;
            transactions = txs_in_canister;
            archived_transactions;
        };
    };

    public func backup(
        memoryController : MemoryController.MemoryController,
        token : T.TokenTypes.TokenData,
        backupParameter : TypesBackupRestore.BackupParameter,
    ) : Result.Result<(isComplete : Bool, data : [Nat8]), Text> {

        BackupService.backup(memoryController, token, backupParameter);
    };

    public func restore(
        memoryController : MemoryController.MemoryController,
        token : T.TokenTypes.TokenData,
        restoreInfo : TypesBackupRestore.RestoreInfo,
    ) : Result.Result<Text, Text> {

        BackupService.restore(memoryController, token, restoreInfo);
    };

    // --------------------------------------------------------------------------------
    // Set or Update values

    /// Set the logo for the token
    public func set_logo(token : TokenData, logo : Text, caller : Principal) : async* SetTextParameterResult {

        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == true) {
            token.logo := logo;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting logo only allowed via minting or admin account.";
                }
            );
        };
        #Ok(token.logo);
    };

    /// Set the fee for each transfer
    public func set_fee(token : TokenData, fee : Nat, caller : Principal) : async* SetBalanceParameterResult {

        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == true) {
            if (fee >= 10_000 and fee <= 1_000_000_000) {
                token.fee := fee;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: fee must be a value between 10_000 and 1_000_000_000.";
                    }
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting fee only allowed via minting or admin account.";
                }
            );
        };
        #Ok(token.fee);
    };

    /// Set the number of decimals specified for the token
    public func set_decimals(token : TokenData, decimals : Nat8, caller : Principal) : async* SetNat8ParameterResult {

        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == true) {
            if (decimals >= 2 and decimals <= 12) {
                token.decimals := decimals;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: decimals must be a value between 2 and 12.";
                    }
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting decimals only allowed via minting or admin account.";
                }
            );
        };
        #Ok(token.decimals);
    };

    /// Set the minimum burn amount
    public func set_min_burn_amount(token : TokenData, min_burn_amount : Nat, caller : Principal) : async* SetBalanceParameterResult {

        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == true) {
            if (min_burn_amount >= 10_000 and min_burn_amount <= 1_000_000_000_000) {
                token.min_burn_amount := min_burn_amount;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: minimum burn amount must be a value between 10_000 and 1_000_000_000_000.";
                    }
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting minimum burn amount only allowed via minting or admin account.";
                }
            );
        };
        #Ok(token.min_burn_amount);
    };

    /// Set the name of the token
    public func set_name(token : TokenData, name : Text, caller : Principal) : async* SetTextParameterResult {

        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == true) {
            token.name := name;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting name only allowed via minting  or admin account.";
                }
            );
        };
        #Ok(token.name);
    };

    /// Set the symbol of the token
    public func set_symbol(token : TokenData, symbol : Text, caller : Principal) : async* SetTextParameterResult {
        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == true) {
            token.symbol := symbol;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting symbol only allowed via minting or admin account.";
                }
            );
        };
        #Ok(token.symbol);
    };

    // --------------------------------------------------------------------------------


    // #region HelperMethods

    private func transaction_contains_principal(tx : Transaction, principal : Principal) : Bool {

        var found : Bool = false;
        switch (tx.transfer) {
            case (?transfer) {

                if (transfer.to.owner == principal or transfer.from.owner == principal) {
                    found := true;
                };
            };
            case (_) {
                // do nothing
            };

        };

        if (found == false) {
            switch (tx.mint) {
                case (?mint) {
                    if (mint.to.owner == principal) {
                        found := true;
                    };
                };
                case (_) {
                    // do nothing
                };
            };
        };

        if (found == false) {
            switch (tx.burn) {
                case (?burn) {
                    if (burn.from.owner == principal) {
                        found := true;
                    };
                };
                case (_) {
                    // do nothing
                };
            };
        };

        return found;
    };

    private func get_transactions_by_principal_count_internal(token : TokenData, principal : Principal) : async* (Nat, Nat) {
        var countFoundInCachedTx : Nat = 0;

        let { archive; transactions } = token;
        let localTransactionsCount = SB.size(transactions);

        for (index in Iter.range(0, localTransactionsCount)) {

            let cachedTxOrNull : ?Transaction = SB.getOpt(transactions, index);

            switch (cachedTxOrNull) {
                case (?cachedTx) {

                    if (transaction_contains_principal(cachedTx, principal) == true) {
                        countFoundInCachedTx := countFoundInCachedTx + 1;
                    };
                };
                case (_) {
                    // do nothing
                };
            };
        };

        var countFoundInArchive : Nat = 0;
        if (archive.stored_txs > 0) {
            countFoundInArchive := await archive.canister.get_transactions_by_principal_count(principal);
        };

        return (countFoundInCachedTx, countFoundInArchive);
    };

    // private func get_cached_transactions_array(token : TokenData) : [Transaction] {

    //     let { transactions } = token;
    //     let localTransactionsCount = SB.size(transactions);

    //     let result = Buffer.Buffer<Transaction>(localTransactionsCount);

    //     for (index in Iter.range(0, localTransactionsCount)) {

    //         let cachedTxOrNull : ?Transaction = SB.getOpt(transactions, index);
    //         switch (cachedTxOrNull) {
    //             case (?cachedTx) {
    //                 // we want to have the reverse order
    //                 result.insert(0, cachedTx);
    //             };
    //             case (_) {
    //                 // do nothing
    //             };

    //         };
    //     };

    //     return Buffer.toArray(result);
    // };


    // #endregion

};
