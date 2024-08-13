import Result "mo:base/Result";
import Principal "mo:base/Principal";
import TransactionTypes "Types.Transaction";
import List "mo:base/List";

module {    
  
   private type Transaction = TransactionTypes.Transaction;
   private type TxIndex = TransactionTypes.TxIndex;
   private type GetTransactionsRequest = TransactionTypes.GetTransactionsRequest;
   private type TransactionRange = TransactionTypes.TransactionRange;
    
   ///For holding all the canister-id's for the dynamically created archive-canisters
   public type ArchiveCanisterIds ={
        var canisterIds: List.List<Principal>;
   };

    /// The Interface for the Archive canister
    public type ArchiveInterface = actor {

        //Initialize method
        init: shared (first_tx_number:Nat, max_memory:Nat, max_heap:Nat) -> async Principal;

        /// Appends the given transactions to the archive.
        /// > Only the Ledger canister is allowed to call this method
        append_transactions : shared ([Transaction]) -> async Result.Result<(), Text>;

        /// Returns the total number of transactions stored in the archive
        total_transactions : shared query () -> async Nat;

        /// Returns the transaction at the given index
        get_transaction : shared query(TxIndex) -> async ?Transaction;

        /// Returns the transactions in the given range
        get_transactions : shared query(GetTransactionsRequest) -> async TransactionRange;

        // Retrieves a list of transactions associated with a specific principal.
        // Parameters:
        // - Principal: The principal whose transactions are to be retrieved.
        // - Nat: The starting index for the transactions.
        // - Nat: The number of transactions to retrieve.
        // Returns: A list of transactions.
        get_transactions_by_principal: shared query(Principal, Nat, Nat) -> async [Transaction];
        
        // Retrieves the total count of transactions associated with a specific principal.
        // Parameters:
        // - Principal: The principal whose transaction count is to be retrieved.
        // Returns: The total number of transactions.
        get_transactions_by_principal_count: shared query(Principal) -> async Nat;

        // Retrieves the index of the first transaction in the archive.
        get_first_tx : shared query () -> async Nat;
        
        // Retrieves the index of the last transaction in the archive.
        get_last_tx : shared query () -> async Nat;
        
        // Retrieves the previous archive interface in the chain.
        get_prev_archive : shared query () -> async ArchiveInterface;
        
        // Retrieves the next archive interface in the chain.
        get_next_archive : shared query () -> async ArchiveInterface;
        
        // Sets the previous archive interface in the chain.
        set_prev_archive : shared (ArchiveInterface) -> async Result.Result<(), Text>;
        
        // Sets the next archive interface in the chain.
        set_next_archive : shared (ArchiveInterface) -> async Result.Result<(), Text>;
        
        // Checks if the memory is full.
        memory_is_full : shared query () -> async Bool;
        
        // Retrieves the remaining memory capacity.
        remaining_memory_capacity : shared query () -> async Nat;
        
        // Retrieves the maximum memory capacity.
        max_memory : shared query () -> async Nat;
        
        // Retrieves the total used memory.
        memory_total_used : shared query () -> async Nat;
        
        // Retrieves the remaining heap capacity.
        remaining_heap_capacity : shared query () -> async Nat;
        
        // Retrieves the maximum heap capacity.
        heap_max : shared query () -> async Nat;
        
        // Retrieves the total used heap.
        heap_total_used : shared query () -> async Nat;
        
        // Retrieves the available cycles.
        cycles_available: shared query () -> async Nat;
        
        // Deposits cycles into the canister.
        deposit_cycles: shared () -> async ();
    };


    /// The details of the archive canister
    public type ArchiveData = {
        /// The reference to the archive canister
        var canister : ArchiveInterface;

        /// The number of transactions stored in the archive
        var stored_txs : Nat;
    };


};