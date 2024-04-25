import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Blobify "mo:memory-buffer/Blobify";
import CommonTypes "../../../Types/Types.Common";
import T "../../../Types/Types.All";
import TypesBackup "../../../Types/Types.BackupRestore";
import TypesAccount "../../../Types/Types.Account";
import TypesToken "../../../Types/Types.Token";
import Utils "../Utils/Utils";
import Converters "../../Converters/Converters";
import MemoryController "../../../Modules/Token/MemoryController/MemoryController";
import SlicesImplementation "../Implementations/SLICES.Implementation";
import Account "../../../Modules/Token/Account/Account";

module {

    let { SB } = Utils;

    public func Backup(
        memoryController : MemoryController.MemoryController,
        token:T.TokenTypes.TokenData,
        backupType:TypesBackup.BackupType,
        backupParameterOrNull:?TypesBackup.BackupParameter
        ):Result.Result<(isComplete:Bool, data:[Nat8]), Text>{

        var currentIndex:Nat = 0;
        var chunkCount:Nat = 0;
        switch(backupParameterOrNull){
            case (?backupParameter){
            currentIndex:=backupParameter.currentIndex;
            chunkCount:=backupParameter.chunkCount;  
            };
            case (_)
            {
                // do nothing
            };
        };

        switch(backupType){

            case (#tokenCommonData){
                // return token maindata as Nat8 array
                let result:(Bool, [Nat8]) = (true,Nat8ArrayFromTokenMainData(token));
                return #ok(result);
            };
            case (#initiateBackup){
                //memoryController.Model.Settings.backupStateInfo.state := #initiated(Time.now());

            };        
            case (#tokenAccounts){                              
                let result:(Bool, [Nat8]) = Nat8ArrayFromAccountHolders(token,currentIndex, chunkCount);
                return #ok(result);

            };
            case (#tokenFeeWhitelistedPrincipals)
            {                                
                let result:(Bool, [Nat8]) = (true,Nat8ArrayFromTokenFeeWhiteListedPrincipals(token));
                return #ok(result);
            };
               
            case (#tokenTokenAdmins){

                let result:(Bool, [Nat8]) = (true,Nat8ArrayFromAdmins(token));
                return #ok(result);
            }; 
            case (#tokenTransactionsBuffer){

                let result:(Bool, [Nat8]) = Nat8ArrayFromTransactionBuffer(token, currentIndex, chunkCount);
                return #ok(result);
            };
            
            case (_)
            {

            };
        };

        return #err("error");
    };


    private func Nat8ArrayFromTokenMainData(token:T.TokenTypes.TokenData):[Nat8]{
        Converters.ConvertToTokenMainDataNat8Array(token);
    };

    private func Nat8ArrayToTokenMainData(array:[Nat8]):?TypesBackup.BackupCommonTokenData{
        Converters.ConvertToTokenMainDataFromNat8Array(array);
    };

    private func Nat8ArrayFromAccountHolders(token:T.TokenTypes.TokenData, currentIndex:Nat, chunkCount:Nat):(isLastChunk:Bool,[Nat8]){

        let holders:[T.AccountTypes.AccountBalanceInfo] = 
                SlicesImplementation.get_holders(
                    token, Option.make(currentIndex), 
                    Option.make(chunkCount)
                );
        var isLastChunk:Bool = false;
        if (Array.size(holders) < chunkCount){
            isLastChunk:=true;
        };
        (isLastChunk, Converters.ConvertAccountHoldersToNat8Array(holders));
    };

    private func Nat8ArrayToAccountHolders(array:[Nat8]):?[T.AccountTypes.AccountBalanceInfo]{
        Converters.ConvertToAccountGoldersFromNat8Array(array);
    };

    private func Nat8ArrayFromTokenFeeWhiteListedPrincipals(token:T.TokenTypes.TokenData):[Nat8]{
        Blob.toArray(to_candid(List.toArray<Principal>(token.feeWhitelistedPrincipals)));
    };

    private func Nat8ArrayToTokenFeeWhiteListedPrincipals(array:[Nat8]):[Principal]{
         let resultOrNull:?[Principal] = from_candid(Blob.fromArray(array));
         switch(resultOrNull) {
            case(?result) { return result; };
            case(null) { return []; };
         };
    };


    private func Nat8ArrayFromAdmins(token:T.TokenTypes.TokenData):[Nat8]{
        Blob.toArray(to_candid(Account.list_admin_users(token)));
    };

    private func Nat8ArrayToTokenAdmins(array:[Nat8]):[Principal]{        
         let resultOrNull:?[Principal] = from_candid(Blob.fromArray(array));
         switch(resultOrNull) {
            case(?result) { return result; };
            case(null) { return []; };
         }; 
    };

    private func Nat8ArrayFromTransactionBuffer(token:T.TokenTypes.TokenData,currentIndex:Nat, chunkCount:Nat):(isLastChunk:Bool,[Nat8]){

         let transactions:[T.TransactionTypes.Transaction] = 
                SlicesImplementation.get_internal_transactions(
                    token, Option.make(currentIndex), 
                    Option.make(chunkCount)
                );
        var isLastChunk:Bool = false;
        if (Array.size(transactions) < chunkCount){
            isLastChunk:=true;
        };
        (isLastChunk,Blob.toArray(to_candid(transactions)));
    };

    private func Nat8ArrayToTransactionBuffer(array:[Nat8]):[T.TransactionTypes.Transaction]{        
        
         let resultOrNull:?[T.TransactionTypes.Transaction] = from_candid(Blob.fromArray(array));
         switch(resultOrNull) {
            case(?result) { return result; };
            case(null) { return []; };
         };   
    };


};