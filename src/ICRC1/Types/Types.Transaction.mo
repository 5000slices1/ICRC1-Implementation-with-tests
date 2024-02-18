import Deque "mo:base/Deque";
import List "mo:base/List";
import Time "mo:base/Time";
import Result "mo:base/Result";

import STMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";

import CommonTypes "Types.Common";
import AccountTypes "Types.Account";

module {

    private type Balance = CommonTypes.Balance;
    private type TxLog = StableBuffer.StableBuffer<Transaction>;
    private type Subaccount = AccountTypes.Subaccount;
    private type Account = AccountTypes.Account;
    private type EncodedAccount = AccountTypes.EncodedAccount;
    private type StableBuffer<T> = StableBuffer.StableBuffer<T>;
    private type StableTrieMap<K, V> = STMap.StableTrieMap<K, V>;

    public type BlockIndex = Nat;
    public type Memo = Blob;
    public type Timestamp = Nat64;
    public type Duration = Nat64;
    public type TxIndex = Nat;
    public type TxCandidBlob = Blob;

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time : Timestamp };
    };

    public type TxKind = {
        #mint;
        #burn;
        #transfer;
    };

    public type TransferResult = {
        #Ok : TxIndex;
        #Err : TransferError;
    };

    public type TransferError = TimeError or {
        #BadFee : { expected_fee : Balance };
        #BadBurn : { min_burn_amount : Balance };
        #InsufficientFunds : { balance : Balance };
        #Duplicate : { duplicate_of : TxIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    ///Mint-Type
    public type Mint = {
        to : Account;
        amount : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    ///Burn arguments type
    public type BurnArgs = {
        from_subaccount : ?Subaccount;
        amount : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    ///Burn type
    public type Burn = {
        from : Account;
        amount : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    /// Arguments for a transfer operation
    public type TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;

        /// The time at which the transaction was created.
        /// If this is set, the canister will check for duplicate transactions and reject them.
        created_at_time : ?Nat64;
    };

    ///Transfer type
    public type Transfer = {
        from : Account;
        to : Account;
        amount : Balance;
        fee : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    /// Internal representation of a transaction request
    public type TransactionRequest = {
        kind : TxKind;
        from : Account;
        to : Account;
        amount : Balance;
        fee : Balance;
        memo : ?Blob;
        created_at_time : ?Nat64;
        encoded : {
            from : EncodedAccount;
            to : EncodedAccount;
        };
    };

    ///Transaction information.
    public type Transaction = {
        kind : Text;
        mint : ?Mint;
        burn : ?Burn;
        transfer : ?Transfer;
        index : TxIndex;
        timestamp : Timestamp;
    };

    // Rosetta API
    /// The type to request a range of transactions from the ledger canister
    public type GetTransactionsRequest = {
        start : TxIndex;
        length : Nat;
    };

    ///If multiple transactions are requested
    public type TransactionRange = {
        transactions : [Transaction];
    };

    ///callback function
    public type QueryArchiveFn = shared query (GetTransactionsRequest) -> async TransactionRange;

    ///This is included in the response type 'GetTransactionsResponse'
    public type ArchivedTransaction = {
        /// The index of the first transaction to be queried in the archive canister
        start : TxIndex;
        /// The number of transactions to be queried in the archive canister
        length : Nat;

        /// The callback function to query the archive canister
        callback : QueryArchiveFn;
    };

    ///The actual response-type for getting multiple transactions
    public type GetTransactionsResponse = {
        /// The number of valid transactions in the ledger and archived canisters that are in the given range
        log_length : Nat;

        /// the index of the first tx in the `transactions` field
        first_index : TxIndex;

        /// The transactions in the ledger canister that are in the given range
        transactions : [Transaction];

        /// Pagination request for archived transactions in the given range
        archived_transactions : [ArchivedTransaction];
    };

    //Icrc2 types:

    public type Allowance = { allowance : Nat; expires_at : ?Nat64 };
    public type AllowanceArgs = { account : Account; spender : Account };

    public type Approve = {
        fee : ?Nat;
        from : Account;
        memo : ?[Nat8];
        created_at_time : ?Nat64;
        amount : Nat;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        spender : Account;
    };

    public type ApproveArgs = {
        fee : ?Nat;
        memo : ?[Nat8];
        from_subaccount : ?[Nat8];
        created_at_time : ?Nat64;
        amount : Nat;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        spender : Account;
    };

    public type ApproveError = {
        #GenericError : { message : Text; error_code : Nat };
        #TemporarilyUnavailable;
        #Duplicate : { duplicate_of : Nat };
        #BadFee : { expected_fee : Nat };
        #AllowanceChanged : { current_allowance : Nat };
        #CreatedInFuture : { ledger_time : Nat64 };
        #TooOld;
        #Expired : { ledger_time : Nat64 };
        #InsufficientFunds : { balance : Nat };
    };

    public type TransferFromArgs = {
        to : Account;
        fee : ?Nat;
        spender_subaccount : ?[Nat8];
        from : Account;
        memo : ?[Nat8];
        created_at_time : ?Nat64;
        amount : Nat;
    };

    public type TransferFromError = {
        #GenericError : { message : Text; error_code : Nat };
        #TemporarilyUnavailable;
        #InsufficientAllowance : { allowance : Nat };
        #BadBurn : { min_burn_amount : Nat };
        #Duplicate : { duplicate_of : Nat };
        #BadFee : { expected_fee : Nat };
        #CreatedInFuture : { ledger_time : Nat64 };
        #TooOld;
        #InsufficientFunds : { balance : Nat };
    };


    public type ApproveResponse = {
        #Ok : Nat;
        #Err : ApproveError;
    };

     public type TransferFromResponse = {
        #Ok : Nat;
        #Err : TransferFromError;
    };

};
