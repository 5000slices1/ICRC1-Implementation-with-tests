import Result "mo:base/Result";
import Principal "mo:base/Principal";
import TransactionTypes "Types.Transaction";
import List "mo:base/List";
import TransactionType "Types.Transaction";
import AccountTypes "Types.Account";

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
        init: shared (first_tx_number:Nat) -> async Principal;

        /// Appends the given transactions to the archive.
        /// > Only the Ledger canister is allowed to call this method
        append_transactions : shared ([Transaction]) -> async Result.Result<(), Text>;

        /// Returns the total number of transactions stored in the archive
        total_transactions : shared query () -> async Nat;

        /// Returns the transaction at the given index
        get_transaction : shared query (TxIndex) -> async ?Transaction;

        /// Returns the transactions in the given range
        get_transactions : shared query (GetTransactionsRequest) -> async TransactionRange;

        get_first_tx : shared query () -> async Nat;

        get_last_tx : shared query () -> async Nat;

        get_prev_archive : shared query () -> async ArchiveInterface;

        get_next_archive : shared query () -> async ArchiveInterface;
     
        set_prev_archive : shared (ArchiveInterface) -> async Result.Result<(), Text>;

        set_next_archive : shared (ArchiveInterface) -> async Result.Result<(), Text>;

        memory_is_full : shared query () -> async Bool;
        remaining_memory_capacity : shared query () -> async Nat;
        max_memory : shared query () -> async Nat;
        memory_total_used : shared query () -> async Nat;
        remaining_heap_capacity : shared query () -> async Nat;
        heap_max : shared query () -> async Nat;
        heap_total_used : shared query () -> async Nat;

        cycles_available:shared query() -> async Nat;

        deposit_cycles:shared () -> async ();
    };


    /// The details of the archive canister
    public type ArchiveData = {
        /// The reference to the archive canister
        var canister : ArchiveInterface;

        /// The number of transactions stored in the archive
        var stored_txs : Nat;
    };


};