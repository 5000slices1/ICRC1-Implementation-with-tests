import Prim "mo:prim";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Option "mo:base/Option";
import ArchiveTypes "../Types/Types.Archive";
import TransactionTypes "../Types/Types.Transaction";
import { ConstantTypes } = "../Types/Types.All";
import HashList "mo:memory-hashlist";
import HashListType "mo:memory-hashlist/modules/libMemoryHashList";
import HashTable "mo:memory-hashtable";
import HashTableType "mo:memory-hashtable/modules/memoryHashTable";
import MemoryRegion "mo:memory-region/MemoryRegion";


shared ({ caller = ledger_canister_id }) actor class Archive() : async ArchiveTypes.ArchiveInterface = this {

    private let transactionsKey : Blob = HashList.Blobify.Text.to_blob("Transactions");
    private let userTransactionsPreKey : Blob = HashList.Blobify.Text.to_blob("UserTransactions");

    private let txIndexPreKey : Blob = HashList.Blobify.Text.to_blob("TxIndex");

    stable var memoryStorageHashList = HashList.get_new_memory_storage(0);
    stable var memoryStorageHashTable = HashTable.get_new_memory_storage(0);

    private let hashList : HashListType.libMemoryHashList = HashList.MemoryHashList(memoryStorageHashList);
    private let hashTable : HashTableType.MemoryHashTable = HashTable.MemoryHashTable(memoryStorageHashTable);

    private type GetTransactionsRequest = TransactionTypes.GetTransactionsRequest;
    private type TransactionRange = TransactionTypes.TransactionRange;
    private type TxIndex = TransactionTypes.TxIndex;
    private type Transaction = TransactionTypes.Transaction;
    private type MemoryBlock = {
        offset : Nat64;
        size : Nat;
    };

    stable var prevArchive : ArchiveTypes.ArchiveInterface = actor ("aaaaa-aa");
    stable var nextArchive : ArchiveTypes.ArchiveInterface = actor ("aaaaa-aa");
    stable var first_tx_index_number : Nat = 0;
    stable var last_tx_index_number_plus_one : Nat = 0;
    stable var at_least_one_transaction_was_added:Bool = false;

    stable var canisterId : Principal = Principal.fromText("aaaaa-aa");
    stable var wasInitialized = false;

    //These fields are defined here (as stable),  and not inside 'Types.Constants.mo', because these values must not change for the canister.
    stable let MAX_MEMORY = 27917287424; // approx 26 GiB
    stable let MAX_HEAP_SIZE = 2018634629; // approx 1.88 GiB

    public shared ({ caller }) func init(first_tx_number : Nat) : async Principal {
        
        if (caller != ledger_canister_id) {
            throw Error.reject("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        if (wasInitialized) {
            return canisterId;
        };

        // Set first and last index number
        first_tx_index_number := first_tx_number;
        last_tx_index_number_plus_one := first_tx_number;

        canisterId := Principal.fromActor(this);
        wasInitialized := true;
        canisterId;
    };

    public shared query func get_prev_archive() : async ArchiveTypes.ArchiveInterface {
        prevArchive;
    };

    public shared query func get_next_archive() : async ArchiveTypes.ArchiveInterface {
        nextArchive;
    };

    public shared query func get_first_tx() : async Nat {
        first_tx_index_number;
    };

    public shared query func get_last_tx() : async Nat {

        if (at_least_one_transaction_was_added == false){
            return 0;
        };
        
        last_tx_index_number_plus_one - 1;
    };

    public shared ({ caller }) func set_prev_archive(prev_archive : ArchiveTypes.ArchiveInterface) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        prevArchive := prev_archive;

        #ok();
    };

    public shared ({ caller }) func set_next_archive(next_archive : ArchiveTypes.ArchiveInterface) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        nextArchive := next_archive;

        #ok();
    };

    public shared ({ caller }) func append_transactions(txs : [Transaction]) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        var arraySize = Array.size(txs);
        if (arraySize == 0) {
            return #err("At least one transaction is needed");
        };

        let lastArrayIndex : Nat = arraySize - 1;
        for (index in Iter.range(0, lastArrayIndex)) {            
            add_transaction(txs[index]);
        };

        return #ok();
    };

    public shared query func total_transactions() : async Nat {
        let indexOrNull : ?Nat = hashList.get_last_index(transactionsKey);
        switch (indexOrNull) {
            case (?index) {
                index + 1;
            };
            case (_) {
                return 0;
            };
        };
    };

    public shared query func get_transaction(tx_index : TxIndex) : async ?Transaction {

        let indexResult = get_hashlist_index_for_txindex(tx_index);
        if (indexResult.0 == false) {
            return null;
        };

        let resultBlobOrNull : ?Blob = hashList.get_at_index(transactionsKey, indexResult.1);
        switch (resultBlobOrNull) {
            case (?resultBlob) {
                let result : ?Transaction = from_candid (resultBlob);
                return result;
            };
            case (_) {
                return null;
            };
        };

    };

    public shared query func get_transactions(req : GetTransactionsRequest) : async TransactionRange {
        
        if (at_least_one_transaction_was_added == false){
            return { transactions = []};
        };
        let { start; length } = req;
        let numberOfTransactionsToReturn = Nat.min(Nat.max(0, length), ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST);
        let startTransactionNumber : Nat = Nat.max(start, first_tx_index_number);

        let hashListIndexResult = get_hashlist_index_for_txindex(startTransactionNumber);
        if (hashListIndexResult.0 == false) {
            return { transactions = [] };
        };
        let firstHashListIndex = hashListIndexResult.1;
        let lastHashListIndex : Nat = Nat.max(firstHashListIndex + numberOfTransactionsToReturn - 1, firstHashListIndex);

        let resultBlobs : [?Blob] = hashList.get_at_range(transactionsKey, firstHashListIndex, lastHashListIndex);

        let size : Nat = Array.size(resultBlobs);
        if (size == 0) {
            return { transactions = [] };
        };

        let buffer = Buffer.Buffer<Transaction>(size);

        for (i in Iter.range(0, size -1)) {
            let blobOrNull : ?Blob = resultBlobs[i];
            switch (blobOrNull) {
                case (?blobValue) {
                    let transactionOrNull : ?Transaction = from_candid (blobValue);
                    switch (transactionOrNull) {
                        case (?transaction) {
                            buffer.add(transaction);
                        };
                        case (null) {};
                    };
                };
                case (_) {
                    // do nothing
                };
            };
        };

        return {
            transactions = Buffer.toArray(buffer);
        };
    };

    public shared query func memory_is_full() : async Bool {
        let remain_memory = remaining_memory_capacity_internal();

        // remaining capacity lower than 1 kb then return true
        if (remain_memory < 1024) {
            return true;
        };

        let remain_heapSize = remaining_heap_capacity_internal();

        // remaining capacity lower than 1 kb then return true
        if (remain_heapSize < 1024) {
            return true;
        };

        return false;
    };

    public shared query func remaining_memory_capacity() : async Nat {
        remaining_memory_capacity_internal();
    };

    public shared query func max_memory() : async Nat {
        MAX_MEMORY;
    };

    public shared query func memory_total_used() : async Nat {
        get_allocated_memory_size();
    };

    public shared query func remaining_heap_capacity() : async Nat {
        remaining_heap_capacity_internal();
    };

    public shared query func heap_max() : async Nat {
        MAX_HEAP_SIZE;
    };

    public shared query func heap_total_used() : async Nat {
        get_heap_size();
    };

    /// Deposit cycles into this archive canister.
    public shared func deposit_cycles<system>() : async () {
        let amount = Cycles.available();
        let accepted = Cycles.accept<system>(amount);
        assert (accepted == amount);
    };

    public shared query func cycles_available() : async Nat {
        Cycles.balance();
    };

    // Helper methods:

    private func add_transaction(transaction:Transaction) {

        // Check if TxIndex already exist, and if so then just return        
        if (at_least_one_transaction_was_added == true and transaction.index < last_tx_index_number_plus_one){            
            return;
        };
        
        let tx_blob : Blob = to_candid (transaction);

        // Add the transaction into hashList
        let result : (Nat, Nat64) = hashList.add(transactionsKey, tx_blob);
        let hashListIndex:Nat = result.0;

        at_least_one_transaction_was_added:=true;
 
    
        // Add transactionIndex as key into hashtable, with hashList index as value, 
        // so that we can later find transaction by a given txIndex.
        // (It is safe to use hashList index as value, because no Transaction will be deleted at any time.)
        let txIndexAsBlob : Blob = HashTable.Blobify.Nat.to_blob(last_tx_index_number_plus_one);
        let hashListIndexAsBlob : Blob = HashTable.Blobify.Nat.to_blob(hashListIndex);
        let txKeyAsBlob = combine_blobs([txIndexPreKey, txIndexAsBlob]);
        ignore hashTable.put(txKeyAsBlob, hashListIndexAsBlob);
        last_tx_index_number_plus_one += 1;
        
        // Add from and to as key into hashtable, with hashList index as value.
        // So that we can later get all transactions for a specific Principal
        if (Option.isSome(transaction.transfer)){

            switch(transaction.transfer){
                case (?transfer){
                    let fromKey = get_user_transaction_key(transfer.from.owner);
                    let toKey = get_user_transaction_key(transfer.to.owner);
                    ignore hashList.add(fromKey, hashListIndexAsBlob);
                    ignore hashList.add(toKey, hashListIndexAsBlob);
                };
                case (_){
                    // do nothing
                }
            }; 
                        
        } else if (Option.isSome(transaction.mint)){
            switch(transaction.mint){
                case (?mint){                    
                    let toKey = get_user_transaction_key(mint.to.owner);                    
                    ignore hashList.add(toKey, hashListIndexAsBlob);
                };
                case (_){
                    // do nothing
                }
            }; 

        } else if (Option.isSome(transaction.burn)) {
            switch(transaction.burn){
                case (?burn){                    
                    let fromKey = get_user_transaction_key(burn.from.owner);                    
                    ignore hashList.add(fromKey, hashListIndexAsBlob);
                };
                case (_){
                    // do nothing
                }
            }; 
        };
                
    };

    private func get_user_transaction_key(principal:Principal): Blob{

        combine_blobs([userTransactionsPreKey,Principal.toBlob(principal)]);
            
    };

    private func get_hashlist_index_for_txindex(tx_index : TxIndex) : (Bool /*found*/, Nat /*index*/) {

        let txIndexAsBlob : Blob = HashTable.Blobify.Nat.to_blob(tx_index);
        let txKeyAsBlob = combine_blobs([txIndexPreKey, txIndexAsBlob]);
        let indexAsBlobOrNull : ?Blob = hashTable.get(txKeyAsBlob);
        switch (indexAsBlobOrNull) {
            case (?hashlistIndex) {
                let index : Nat = HashTable.Blobify.Nat.from_blob(hashlistIndex);
                return (true, index);
            };
            case (_) {
                return (false, 0);
            };
        };
    };

    private func remaining_memory_capacity_internal() : Nat {
        let allocatedSize = get_allocated_memory_size();
        if (allocatedSize >= MAX_MEMORY){
            return 0;
        };

        MAX_MEMORY - get_allocated_memory_size();
    };

    private func remaining_heap_capacity_internal() : Nat {
        let heapSize = get_heap_size();
        if (heapSize >= MAX_HEAP_SIZE){
            return 0;
        };
        MAX_HEAP_SIZE - get_heap_size();
    };

    private func get_allocated_memory_size() : Nat {
        let memInfoHashList = MemoryRegion.memoryInfo(memoryStorageHashList.memory_region);
        let memInfoHashTable = MemoryRegion.memoryInfo(memoryStorageHashTable.memory_region);
        let totalMemoryUsed = memInfoHashList.size + memInfoHashTable.size;
        return totalMemoryUsed;
    };

    private func get_heap_size() : Nat {
        Prim.rts_heap_size();
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
