import List "mo:base/List";
import Principal "mo:base/Principal";
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
    public type Tokens = Nat;

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

    // --------------------------------------------------------------------
    /// ICRC2 allowance

    //     Returns the token allowance that the spender account can transfer from the specified account,
    //     and the expiration time for that allowance, if any. If there is no active approval,
    //     the ledger MUST return { allowance = 0; expires_at = null }.
    public type Allowance = { allowance : Nat; expires_at : ?Nat64 };
    public type AllowanceArgs = { account : Account; spender : Account };

    // --------------------------------------------------------------------

    // --------------------------------------------------------------------
    /// ICRC2 transfer-from

    // (0)
    //      Description:
    //      Transfers a token amount from the from account to the to account using the allowance
    //      of the spender's account (SpenderAccount = { owner = caller; subaccount = spender_subaccount }).
    //      The ledger draws the fees from the from account.
    //
    // (1)
    //     Preconditions:
    //     - The allowance for the SpenderAccount from the from account is large enough to cover the transfer amount
    //       and the fees (icrc2_allowance({ account = from; spender = SpenderAccount }).allowance >= amount + fee).
    //       Otherwise, the ledger MUST return an InsufficientAllowance error.
    //     - The from account holds enough funds to cover the transfer amount and the fees.
    //       (icrc1_balance_of(from) >= amount + fee). Otherwise, the ledger MUST return an InsufficientFunds error.
    //
    // (2)
    //     Postconditions:
    //     - If the from account is not equal to the SpenderAccount, the (from, SpenderAccount)
    //       allowance decreases by the transfer amount and the fees.
    //     - The ledger debited the specified amount of tokens and fees from the from account.
    //     - The ledger credited the specified amount to the to account.

    public type TransferFromArgs = {
        spender_subaccount : ?Subaccount;

        // Transfers a token amount from the from account to the to account using the allowance of the
        // spender's account (SpenderAccount = { owner = caller; subaccount = spender_subaccount }).
        // The ledger draws the fees from the from account.
        from : Account;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Memo;
        created_at_time : ?Nat64;
    };

    /// Internal representation of a Transaction From request
    public type TransactionFromRequest = {
        kind : TxKind;
        from : Account;
        to : Account;
        spender : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Memo;
        created_at_time : ?Nat64;
        encoded : {
            from : EncodedAccount;
            to : EncodedAccount;
            spender : EncodedAccount;
        };
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

    public type TransferFromResponse = {
        #Ok : Nat;
        #Err : TransferFromError;
    };

    // --------------------------------------------------------------------

    //  -------------------------------------------------------------------
    /// ICRC2 Approval

    /// Arguments for an approve operation

    // Specification source: https://github.com/chichangb/ICRC-1/blob/main/standards/ICRC-2/README.md
    //
    // (1)
    //    The number of transfers the spender can initiate from the caller's account
    //    is unlimited as long as the total amounts and fees of these
    //    transfers do not exceed the allowance.
    //    -> This is the default behaviour from the ICRC2 specifiction. But in this implementation
    //       we can overrule this by the type 'UserApprovalSettings', to allow transfer_from only one time if wanted.
    //       (not implemented, yet)
    //
    // (2)
    //    The call resets the allowance and the expiration date for the spender account to the given values.
    //
    // (3)
    //    Preconditions:
    //    - The caller has enough fees on the { owner = caller; subaccount = from_subaccount } account to pay the approval fee.
    //    - If the expires_at field is set, it's greater than the current ledger time.
    //    - If the expected_allowance field is set, it's equal to the current allowance for the spender.
    // (4)
    //    Postconditions:
    //    - The spender's allowance for the { owner = caller; subaccount = from_subaccount } is equal to the given amount.
    //
    public type ApproveArgs = {
        from_subaccount : ?Subaccount;

        // The ledger SHOULD reject the call if the spender account owner is equal to the source account owner.
        spender : Account;

        // (1)
        //    The caller does not need to have the full token amount on the specified account
        //    for the approval to succeed, just enough tokens to pay the approval fee
        // (2)
        //    The ledger MAY cap the allowance if it is too large (for example, larger than the total token supply).
        //    For example, if there are only 100 tokens, and the ledger receives an approval for 120 tokens,
        //    the ledger may cap the allowance to 100.
        amount : Balance;

        // If the expected_allowance field is set, the ledger MUST ensure that the current allowance
        // for the spender from the caller's account is equal to the given value and return
        // the AllowanceChanged error otherwise.
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        fee : ?Balance;
        memo : ?Memo;
        created_at_time : ?Nat64;
    };

    /// Internal representation of an Approve request
    public type ApproveRequest = {
        from : Account;
        spender : Account;
        amount : Balance;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        fee : ?Balance;
        memo : ?Memo;
        created_at_time : ?Nat64;
        encoded : {
            from : EncodedAccount;
            spender : EncodedAccount;
        };
    };

    public type ApproveResult = {
        #Ok : Nat;
        #Err : ApproveError;
    };

    public type WriteApproveRequest = {
        amount : Balance;
        expires_at : ?Nat64;
        encoded : {
            from : EncodedAccount;
            spender : EncodedAccount;
        };
    };

    public type DbAllowance = {
        allowance : Balance;
        expires_at : ?Nat64;
        encoded : {
            from : EncodedAccount;
            spender : EncodedAccount;
        };
    };

    public type ApproveError = {
        #BadFee : { expected_fee : Nat };

        // The caller does not have enough funds to pay the approval fee.
        #InsufficientFunds : { balance : Nat };

        // The caller specified the [expected_allowance] field, and the current
        // allowance did not match the given value.
        #AllowanceChanged : { current_allowance : Nat };

        // The approval request expired before the ledger had a chance to apply it.
        #Expired : { ledger_time : Nat64 };

        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError : { message : Text; error_code : Nat };

    };

    //The user can define global settings for 'only_one_time_useable' and 'expires_at'.
    //For security users can only set these settings if they hold at least 1.0 token in wallet.
    public type UserApprovalSettings = {

        //If this is set to true then new 'ApprovalItem' will have set the 'one_time_useable' to true
        global_only_one_time_useable : ?Bool;

        //If this is set then new 'ApprovalItem' will have set the same expirationTime.
        //Regardless what was specified in 'ApproveArgs'
        global_expiration_time : ?Nat64;

        //if 'global_only_one_time_useable' is set to true, but for some principals we
        //do not want this, we can add these principals into this list.
        //-> For security reasons (memory issue) this list can only contain max 100 items
        global_only_one_time_useable_disabled : List.List<Principal>;

        //if 'global_expiration_time' is set, but for some principals we
        //do not want this, we can add these principals into this list.
        //-> For security reasons (memory issue) this list can only contain max 100 items
        global_expiration_time_disabled : List.List<Principal>;
    };

    //  -------------------------------------------------------------------

};
