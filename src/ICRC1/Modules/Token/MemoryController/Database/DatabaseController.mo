import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import T "../../../../Types/Types.All";
import ModelType "../../../../Types/Types.Model";
import HashList "mo:memory-hashlist";
import HashListType "mo:memory-hashlist/modules/libMemoryHashList";
import HashTable "mo:memory-hashtable";
import HashTableType "mo:memory-hashtable/modules/memoryHashTable";
import AccountTypes "../../../../Types/Types.Account";
import Account "../../../../Modules/Token/Account/Account";

module {

    public class DatabaseController(databaseStorages : ModelType.DatabaseStorages) {

        private type EncodedAccount = AccountTypes.EncodedAccount;

        private let hashList : HashListType.libMemoryHashList = HashList.MemoryHashList(databaseStorages.memoryDatabaseForHashList);
        private let hashTable : HashTableType.MemoryHashTable = HashTable.MemoryHashTable(databaseStorages.memoryDatabaseForHashTable);
        private let preKeyAllowanceSpenderList : Blob = HashList.Blobify.Text.to_blob("allowance_spenders");
        private let preKeyAllowance : Blob = HashList.Blobify.Text.to_blob("allowance");

        public func write_approval(app_req : T.TransactionTypes.WriteApproveRequest) : T.TransactionTypes.ApproveResult {

            let fromAsBlob : Blob = app_req.encoded.from;
            let spenderAsBlob : Blob = app_req.encoded.spender;

            let spenderListKey : Blob = get_allowance_spender_list_key(fromAsBlob);
            let allowanceKey : Blob = get_allowance_key(fromAsBlob, spenderAsBlob);

            // add spender account for the owner if not already existing
            if (hashTable.get(allowanceKey) == null) {
                ignore hashList.add(spenderListKey, spenderAsBlob);
            };

            // add/replace approval request

            // For now DbAllowance and WriteApproveRequest have the same structure
            let dbAllowance : T.TransactionTypes.DbAllowance = {
                app_req with allowance = app_req.amount
            };

            let dbAllowance_as_blob : Blob = to_candid (dbAllowance);
            ignore hashTable.put(allowanceKey, dbAllowance_as_blob);

            return #Ok(app_req.amount);
        };

        public func get_allowance_list(owner : AccountTypes.Account):[T.TransactionTypes.AllowanceInfo]{

            let ownerEncodedAccount : EncodedAccount = Account.encode(owner);
            let spenderListKey : Blob = get_allowance_spender_list_key(ownerEncodedAccount);
            
            let lastIndexOrNull:?Nat = hashList.get_last_index(spenderListKey);
            var lastIndex : Nat = 0;

            switch (lastIndexOrNull) {
                case (?lastIndexValue) {
                        lastIndex := lastIndexValue;
                    };                                    
                case (_) {
                    return [];
                };
            };

            let result = Buffer.Buffer<T.TransactionTypes.AllowanceInfo>(lastIndex);

            let spenderBlobs:[?Blob] = hashList.get_at_range(spenderListKey, 0, lastIndex);

            for (index in Iter.range(0, lastIndex)) {
                
                let spenderAsBlob : ?Blob = spenderBlobs[index];
                if (spenderAsBlob != null) {
                    
                    switch (spenderAsBlob) {
                        case (?spenderAsBlobValue) {

                            let allowanceOrNull:?T.TransactionTypes.DbAllowance = get_allowance_internal(ownerEncodedAccount, spenderAsBlobValue);

                            let spenderOrNull : ?AccountTypes.Account = Account.decode(spenderAsBlobValue);
                            var foundSpender : AccountTypes.Account =
                            {
                                 owner = Principal.fromText("aaaaa-aa"); 
                                 subaccount = null; 
                            };
                            var found = false;
                            switch (spenderOrNull) {
                                case (?spenderValue) {
                                    foundSpender := spenderValue;
                                    found:=true;
                                };
                                case (_) {
                                    // do nothing
                                };
                            };
                            if (found == true){

                                switch (allowanceOrNull) {
                                    case (?allowanceItem) {
                                        
                                        let resultItem : T.TransactionTypes.AllowanceInfo = {
                                            allowance = allowanceItem.allowance;
                                            expires_at = allowanceItem.expires_at;
                                            spender = foundSpender;
                                        };    
                                        result.add(resultItem);                     
                                    };
                                    case (_) {
                                        // do nothing
                                    };
                                };
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

        public func get_allowance(owner : AccountTypes.Account, spender : AccountTypes.Account) : T.TransactionTypes.Allowance {

            let ownerEncodedAccount : EncodedAccount = Account.encode(owner);
            let spenderEncodedAccount : EncodedAccount = Account.encode(spender);

            let allowanceResultOrNull = get_allowance_internal(ownerEncodedAccount, spenderEncodedAccount);
            switch (allowanceResultOrNull) {
                case (?allowanceResult) {
                    let result : T.TransactionTypes.Allowance = {
                        allowance = allowanceResult.allowance;
                        expires_at = allowanceResult.expires_at;
                    };
                    return result;
                };
                case (_) {
                    let result : T.TransactionTypes.Allowance = {
                        allowance = 0;
                        expires_at = null;
                    };
                    return result;
                };
            };

        };

        public func reduce_allowance_amount(owner : AccountTypes.Account, spender : AccountTypes.Account, reduceByAmount : T.Balance) {

            let ownerEncodedAccount : EncodedAccount = Account.encode(owner);
            let spenderEncodedAccount : EncodedAccount = Account.encode(spender);
            let allowanceItemOrNull : ?T.TransactionTypes.DbAllowance = get_allowance_internal(ownerEncodedAccount, spenderEncodedAccount);
            switch (allowanceItemOrNull) {
                case (?allowanceItem) {
                    var newAmount:Nat = 0;
                    if (reduceByAmount < allowanceItem.allowance){
                        newAmount:= allowanceItem.allowance - reduceByAmount;
                    };
                    
                    let newAllowance : T.TransactionTypes.DbAllowance = {
                        allowanceItem with allowance = newAmount
                    };

                    let allowanceKey : Blob = get_allowance_key(ownerEncodedAccount, spenderEncodedAccount);
                    let dbAllowance_as_blob : Blob = to_candid (newAllowance);
                    ignore hashTable.put(allowanceKey, dbAllowance_as_blob);
                };
                case (_) {
                    // do nothing
                };
            };
        };

        private func get_allowance_internal(owner : EncodedAccount, spender : EncodedAccount) : ?T.TransactionTypes.DbAllowance {

            let key = get_allowance_key(owner, spender);
            let resultBlobOrNull = hashTable.get(key);
            switch (resultBlobOrNull) {
                case (?resultBlob) {
                    return from_candid (resultBlob);
                };
                case (_) {
                    return null;
                };
            };
        };

        private func get_allowance_key(fromAsBlob : Blob, spenderAsBlob : Blob) : Blob {

            combine_blobs([preKeyAllowance, fromAsBlob, spenderAsBlob]);
        };

        private func get_allowance_spender_list_key(fromAsBlob : Blob) : Blob {
            combine_blobs([preKeyAllowanceSpenderList, fromAsBlob]);
        };

        private func combine_blobs(blobs : [Blob]) : Blob {

            var neededSize = 0;
            for (blob in Iter.fromArray<Blob>(blobs)) {
                neededSize += blob.size();
            };

            let buffer = Buffer.Buffer<Nat8>(neededSize);

            for (blob in Iter.fromArray<Blob>(blobs)) {
                buffer.append(Buffer.fromArray<Nat8>(Blob.toArray(blob)));
            };

            let array = Buffer.toArray(buffer);
            return Blob.fromArray(array);

        };

    };

};
