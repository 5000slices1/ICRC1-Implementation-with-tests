import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Blobify "mo:memory-buffer/Blobify";
import CommonTypes "../../../Types/Types.Common";
import T "../../../Types/Types.All";
import TypesBackupRestore "../../../Types/Types.BackupRestore";
import TypesAccount "../../../Types/Types.Account";
import TypesToken "../../../Types/Types.Token";
import Utils "../Utils/Utils";
import Converters "../../Converters/Converters";
import MemoryController "../../../Modules/Token/MemoryController/MemoryController";
import SlicesImplementation "../Implementations/SLICES.Implementation";
import Account "../../../Modules/Token/Account/Account";
import STMap "mo:StableTrieMap";
import Itertools "mo:itertools/Iter";
import RevIter "mo:itertools/RevIter";
import StableBuffer "mo:StableBuffer/StableBuffer";

module {

    let { SB } = Utils;
    private type AccountBalances = T.AccountTypes.AccountBalances;

    public func restore(
        memoryController : MemoryController.MemoryController,
        token : T.TokenTypes.TokenData,
        restoreInfo : TypesBackupRestore.RestoreInfo,

    ) : Result.Result<Text, Text> {

        switch (restoreInfo.dataType) {
            case (#tokenCommonData) {
                return RestoreFromTokenMainDataNat8Array(token, restoreInfo.bytes);
            };
            case (#tokenAccounts) {

                if (restoreInfo.isFirstChunk == true) {
                    STMap.clear(token.accounts);
                };

                let accountsOrNull : ?[T.AccountTypes.AccountBalanceInfo] = Nat8ArrayToAccountHolders(restoreInfo.bytes);
                switch (accountsOrNull) {
                    case (?accounts) {

                        for (element in RevIter.fromArray(accounts)) {
                            let encodedAccount : TypesAccount.EncodedAccount = Account.encode(element.account);
                            let balance : T.Balance = element.balance;

                            STMap.put(
                                token.accounts,
                                Blob.equal,
                                Blob.hash,
                                encodedAccount,
                                balance,
                            );
                        };
                        return #ok("");
                    };
                    case (_) {
                        return #err("Cannot convert holders array");
                    };
                };

            };

            case (#tokenTransactionsBuffer) {
                
                StableBuffer.clear(token.transactions);
                let transactionBufferOrNull : ?[T.TransactionTypes.Transaction] = Nat8ArrayToTransactionBuffer(restoreInfo.bytes);
                switch (transactionBufferOrNull) {
                    case (?transactionBuffer) {
                        for (element in Iter.fromArray(transactionBuffer)) {                           
                            StableBuffer.add(token.transactions, element);
                        };
                        return #ok("");
                    };
                    case (_) {
                        return #err("Could not convert Token transaction buffer information.");
                    };
                };
            };
            case (_) {
                return #err("Unknown datatype in restoreInfo specified.");
            };
        };

        return #err("");

    };

    public func backup(
        memoryController : MemoryController.MemoryController,
        token : T.TokenTypes.TokenData,
        backupParameter : TypesBackupRestore.BackupParameter,
    ) : Result.Result<(isComplete : Bool, data : [Nat8]), Text> {

        var currentIndex : Nat = Option.get(backupParameter.currentIndex, 0);
        var chunkCount : Nat = Option.get(backupParameter.chunkCount, 0);

        switch (backupParameter.backupType) {

            case (#tokenCommonData) {
                // return token maindata as Nat8 array
                let result : (Bool, [Nat8]) = (true, Nat8ArrayFromTokenMainData(token));
                return #ok(result);
            };
            case (#tokenAccounts) {
                let result : (Bool, [Nat8]) = Nat8ArrayFromAccountHolders(token, currentIndex, chunkCount);
                return #ok(result);

            };
           
            case (#tokenTransactionsBuffer) {

                let result : [Nat8] = Nat8ArrayFromTransactionBuffer(token);
                return #ok(true,result);
            };

            case (_) {
                return #err("error. backup type not recognized.");
            };
        };

        return #err("error");
    };

    private func Nat8ArrayFromTokenMainData(token : T.TokenTypes.TokenData) : [Nat8] {
        Converters.ConvertToTokenMainDataNat8Array(token);
    };

    private func RestoreFromTokenMainDataNat8Array(token : T.TokenTypes.TokenData, array : [Nat8]) : Result.Result<Text, Text> {

        if (Array.size(array) == 0) {
            return #err("No token data found in Nat8 array");
        };

        let commDataOrNull : ?TypesBackupRestore.BackupCommonTokenData = Converters.ConvertToTokenMainDataFromNat8Array(array);
        switch (commDataOrNull) {
            case (?commonData) {
                token.name := commonData.name;
                token.symbol := commonData.symbol;
                token.decimals := commonData.decimals;
                token.defaultFee := commonData.defaultFee;
                token.logo := commonData.logo;
                token.max_supply := commonData.max_supply;
                token.minted_tokens := commonData.minted_tokens;
                token.minting_allowed := commonData.minting_allowed;
                token.burned_tokens := commonData.burned_tokens;
                token.minting_account := commonData.minting_account;
                token.transaction_window := commonData.transaction_window;
                token.min_burn_amount := commonData.min_burn_amount;
                token.permitted_drift := commonData.permitted_drift;

                Utils.emptyList(token.feeWhitelistedPrincipals);
                token.feeWhitelistedPrincipals := commonData.feeWhitelistedPrincipals;

                Utils.emptyList(token.tokenAdmins);
                token.tokenAdmins := commonData.tokenAdmins;

                // restore supported standards
                SB.clear(token.supported_standards);
                for (element in Iter.fromArray(commonData.supported_standards)) {
                    SB.add(token.supported_standards, element);
                };

                return #ok("");
            };
            case (_) {
                return #err("Deserializing TokenCommonData failed.");
            };
        };
    };

    private func Nat8ArrayFromAccountHolders(token : T.TokenTypes.TokenData, currentIndex : Nat, chunkCount : Nat) : (isLastChunk : Bool, [Nat8]) {

        let holders : [T.AccountTypes.AccountBalanceInfo] = SlicesImplementation.get_holders(
            token,
            Option.make(currentIndex),
            Option.make(chunkCount),
        );
        var isLastChunk : Bool = false;
        if (Array.size(holders) < chunkCount) {
            isLastChunk := true;
        };
        (isLastChunk, Converters.ConvertAccountHoldersToNat8Array(holders));
    };

    private func Nat8ArrayToAccountHolders(array : [Nat8]) : ?[T.AccountTypes.AccountBalanceInfo] {
        Converters.ConvertToAccountHoldersFromNat8Array(array);
    };

    private func Nat8ArrayFromTransactionBuffer(token : T.TokenTypes.TokenData) : [Nat8] {      
        Blob.toArray(to_candid (SB.toArray(token.transactions)));
    };

    private func Nat8ArrayToTransactionBuffer(array : [Nat8]) : ?[T.TransactionTypes.Transaction] {

        if (Array.size(array) == 0) {
            return Option.make([]);
        };

        let resultOrNull : ?[T.TransactionTypes.Transaction] = from_candid (Blob.fromArray(array));
        return resultOrNull;
    };

};
