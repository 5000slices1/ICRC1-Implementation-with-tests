import CommonTypes "Types.Common";
import AccountTypes "Types.Account";
import TransactionTypes "Types.Transaction";
import StableBuffer "mo:StableBuffer/StableBuffer";
import Result "mo:base/Result";
import List "mo:base/List";
import ArchiveTypes "Types.Archive";
import CanisterTypes "Types.Canister";
import BackupRestoreTypes "Types.BackupRestore";

module {

    //icrc2 types:
    private type AllowanceArgs = TransactionTypes.AllowanceArgs;
    private type Allowance = TransactionTypes.Allowance;
    private type TransferFromArgs = TransactionTypes.TransferFromArgs;
    private type ApproveArgs = TransactionTypes.ApproveArgs;
    private type ApproveResponse = TransactionTypes.ApproveResult;
    private type TransferFromResponse = TransactionTypes.TransferFromResponse;
    private type TransferFromError = TransactionTypes.TransferFromError;

    //other types:
    private type GetTransactionsResponse = TransactionTypes.GetTransactionsResponse;
    private type GetTransactionsRequest = TransactionTypes.GetTransactionsRequest;
    private type TransferResult = TransactionTypes.TransferResult;
    private type TransferArgs = TransactionTypes.TransferArgs;
    private type Transaction = TransactionTypes.Transaction;

    private type ArchiveData = ArchiveTypes.ArchiveData;
    private type Value = CommonTypes.Value;
    private type Balance = CommonTypes.Balance;

    private type Account = AccountTypes.Account;
    private type EncodedAccount = AccountTypes.EncodedAccount;
    private type AccountBalances = AccountTypes.AccountBalances;
    private type StableBuffer<T> = StableBuffer.StableBuffer<T>;

    ///Single Metadata item-type
    public type MetaDatum = (Text, Value);

    ///This information is used by the token
    public type MetaData = [MetaDatum];

    /// Initial arguments for the setting up the icrc1 token canister
    public type InitArgs = {
        // The name of the token.
        name : Text;

        // The symbol of the token.
        symbol : Text;

        // The number of decimal places the token uses.
        decimals : Nat8;

        // The transaction fee for the token.
        fee : Balance;

        // The logo of the token.
        logo : Text;

        // The account that is authorized to mint new tokens.
        minting_account : Account;

        // The maximum supply of the token.
        max_supply : Balance;

        // The initial balances of the token, represented as a list of account and balance pairs.
        initial_balances : [(Account, Balance)];

        // The minimum amount of tokens that can be burned in a single transaction.
        min_burn_amount : Balance;

        //Only if set to true then minting is allowed
        minting_allowed : Bool;
    };

    /// [InitArgs](#type.InitArgs) with optional fields for initializing a token canister
    public type TokenInitArgs = {
        
        // The name of the token.
        name : Text;

        // The symbol of the token.
        symbol : Text;

        // The number of decimal places the token uses.
        decimals : Nat8;

        // The transaction fee for the token.
        fee : Balance;

        // The logo of the token.
        logo : Text;

        // The maximum supply of the token.
        max_supply : Balance;

        // The initial balances of the token, represented as a list of account and balance pairs.
        initial_balances : [(Account, Balance)];

        // The minimum amount of tokens that can be burned in a single transaction.
        min_burn_amount : Balance;

        /// optional value that defaults to the caller if not provided
        minting_account : ?Account;

        //Only if set to true then minting is allowed
        minting_allowed : Bool;

    };

    /// The state of the token canister
    public type TokenData = {
        
        /// The name of the token
        var name : Text;

        /// The symbol of the token
        var symbol : Text;

        /// The number of decimals the token uses
        var decimals : Nat8;

        /// The fee charged for each transaction
        var fee : Balance;

        /// The logo for the token
        var logo : Text;

        /// The maximum supply of the token
        /// This is set as variable, so that token-amount scaling can be done.
        /// For example initial token-supply-amount is set to 5000
        /// Then later we multiply (as example) the supply with factor 100, so that 500000 supply is now used.
        /// And also all the token-holder balances will be multiplied by that same factor 100.
        /// Therefore the max_supply must be set as variable.
        var max_supply : Balance;

        /// The total amount of minted tokens
        var minted_tokens : Balance;

        // Only if this is set to true then minting is allowed for this token
        var minting_allowed : Bool;

        /// The total amount of burned tokens
        var burned_tokens : Balance;

        /// The account that is allowed to mint new tokens
        /// On initialization, the maximum supply is minted to this account
        var minting_account : Account;

        /// The balances of all accounts
        accounts : AccountBalances;

        var feeWhitelistedPrincipals : AccountTypes.PrincipalsWhitelistedFees;

        var tokenAdmins : AccountTypes.AdminPrincipals;

        /// The standards supported by this token's implementation
        supported_standards : StableBuffer<CommonTypes.SupportedStandard>;

        /// The time window in which duplicate transactions are not allowed
        var transaction_window : Nat;

        /// The minimum amount of tokens that must be burned in a transaction
        var min_burn_amount : Balance;

        /// The allowed difference between the ledger time and the time of the device the transaction was created on
        var permitted_drift : Nat;

        /// The recent transactions that have been processed by the ledger.
        /// Only the last 2000 transactions are stored before being archived.
        transactions : StableBuffer<Transaction>;

        /// The record that stores the details to the archive canister and number of transactions stored in it
        archive : ArchiveData;

    };

    public type SetParameterError = {
        #GenericError : { error_code : Nat; message : Text };
    };

    public type SetTextParameterResult = {
        #Ok : Text;
        #Err : SetParameterError;
    };

    public type SetNat8ParameterResult = {
        #Ok : Nat8;
        #Err : SetParameterError;
    };

    public type SetBalanceParameterResult = {
        #Ok : Balance;
        #Err : SetParameterError;
    };

    /// Interface for the ICRC token canister
    public type Icrc1Interface = actor {

        /// Returns the name of the token
        icrc1_name : shared query () -> async Text;

        /// Returns the symbol of the token
        icrc1_symbol : shared query () -> async Text;

        /// Returns the number of decimals the token uses
        icrc1_decimals : shared query () -> async Nat8;

        /// Returns the fee charged for each transfer
        icrc1_fee : shared query () -> async Balance;

        /// Returns the tokens metadata
        icrc1_metadata : shared query () -> async MetaData;

        /// Returns the total supply of the token
        icrc1_total_supply : shared query () -> async Balance;

        /// Returns the account that is allowed to mint new tokens
        icrc1_minting_account : shared query () -> async ?Account;

        /// Returns the balance of the given account
        icrc1_balance_of : shared query (Account) -> async Balance;

        /// Transfers the given amount of tokens from the sender to the recipient
        icrc1_transfer : shared (TransferArgs) -> async TransferResult;

        /// Returns the standards supported by this token's implementation
        icrc1_supported_standards : shared query () -> async [CommonTypes.SupportedStandard];

    };

    public type Icrc2Interface = actor {

        // Retrieves the allowance for a given spender.
        icrc2_allowance : shared query AllowanceArgs -> async Allowance;

        // Approves a spender to transfer tokens on behalf of the owner.
        icrc2_approve : shared ApproveArgs -> async ApproveResponse;

        // Transfers tokens from one account to another using the allowance mechanism.
        icrc2_transfer_from : shared TransferFromArgs -> async TransferFromResponse;
    };

    /**
     * Represents the interface for the SlicesToken actor.
     */
    public type SlicesTokenInterface = actor {

        // Queries the real fee between two principals
        real_fee : shared query (from : Principal, to : Principal) -> async Balance;

        // Adds a new admin user
        admin_add_admin_user:shared (principal : Principal) -> async Result.Result<Text, Text>;

        // Removes an existing admin user
        admin_remove_admin_user: shared (principal : Principal) -> async Result.Result<Text, Text>;

        // Lists all admin users
        list_admin_users : shared query () -> async [Principal];

        // Adds a principal to the fee whitelist with a specified fee
        feewhitelisting_add_principal : shared (principal : Principal) -> async Result.Result<Text, Text>;

        // Removes a principal from the fee whitelist
        feewhitelisting_remove_principal : shared (principal : Principal) -> async Result.Result<Text, Text>;

        // Gets the list of principals in the fee whitelist
        feewhitelisting_get_list : shared query () -> async [Principal];

        // Retrieves all canister statistics
        all_canister_stats : shared () -> async [CanisterTypes.CanisterStatsResponse];

        // Gets the count of token holders
        get_holders_count : shared query () -> async Nat;

        // Retrieves a list of token holders with optional pagination
        get_holders : shared query (index : ?Nat, count : ?Nat) -> async [AccountTypes.AccountBalanceInfo];

        // Upscales the token amount by a specified number of decimal places
        tokens_amount_upscale : shared (numberOfDecimalPlaces : Nat8) -> async Result.Result<Text, Text>;

        // Downscales the token amount by a specified number of decimal places
        tokens_amount_downscale : shared (numberOfDecimalPlaces : Nat8) -> async Result.Result<Text, Text>;
        
    };

    public type ExtendedTokenInterface = actor {

        
        // Backs up the token data with the given parameters.
        backup : shared (backupParameter : BackupRestoreTypes.BackupParameter) -> async Result.Result<(isComplete : Bool, data : [Nat8]), Text>;

        // Restores the token data with the given restore information.
        restore : shared (RestoreInfo : BackupRestoreTypes.RestoreInfo) -> async Result.Result<Text, Text>;

        // Pauses token operations for a specified number of minutes.
        token_operation_pause : shared (minutes : Nat) -> async Result.Result<Text, Text>;

        // Resumes token operations.
        token_operation_continue : shared () -> async Result.Result<Text, Text>;

        // Retrieves the current status of token operations.
        token_operation_status : shared query () -> async Text;

        // Mints new tokens with the given arguments.
        mint : shared (args : TransactionTypes.Mint) -> async TransactionTypes.TransferResult;

        // Burns tokens with the given arguments.
        burn : shared (args : TransactionTypes.BurnArgs) -> async TransactionTypes.TransferResult;

        // Sets the name of the token.
        set_name : shared (name : Text) -> async SetTextParameterResult;

        // Sets the symbol of the token.
        set_symbol : shared (symbol : Text) -> async SetTextParameterResult;

        // Sets the logo of the token.
        set_logo : shared (logo : Text) -> async SetTextParameterResult;

        // Sets the transaction fee for the token.
        set_fee : shared (fee : Balance) -> async SetBalanceParameterResult;

        // Sets the number of decimals for the token.
        set_decimals : shared (decimals : Nat8) -> async SetNat8ParameterResult;

        // Sets the minimum burn amount for the token.
        set_min_burn_amount : shared (min_burn_amount : Balance) -> async SetBalanceParameterResult;

        // Retrieves the minimum burn amount for the token.
        min_burn_amount : shared query () -> async Balance;

        // Retrieves the total amount of burned tokens.
        get_burned_amount : shared query () -> async Balance;

        // Retrieves the maximum supply of the token.
        get_max_supply : shared query () -> async Balance;

        // Retrieves the archive interface for the token.
        get_archive : shared query () -> async ArchiveTypes.ArchiveInterface;

        // Retrieves the total number of transactions.
        get_total_tx : shared query () -> async Nat;

        // Retrieves the number of stored transactions in the archive.
        get_archive_stored_txs : shared query () -> async Nat;

        // Retrieves a list of transactions based on the given request.
        get_transactions : shared query (TransactionTypes.GetTransactionsRequest) -> async TransactionTypes.GetTransactionsResponse;

        // Retrieves a list of transactions starting from a specific index and up to a specified length.
        get_transactions_by_index: shared (startIndex: Nat, length: Nat) -> async [TransactionTypes.Transaction];
        
        // Retrieves a list of transactions associated with a specific principal, starting from a specific index and up to a specified length.
        get_transactions_by_principal: shared (principal: Principal, startIndex: Nat, length: Nat) -> async [TransactionTypes.Transaction];
        
        // Retrieves the total count of transactions associated with a specific principal.
        get_transactions_by_principal_count: shared (principal: Principal) -> async Nat;

        // Retrieves a specific transaction by its ID.
        get_transaction : shared (tx_id : TransactionTypes.TxIndex) -> async ?TransactionTypes.Transaction;

        // Enables automatic top-up of cycles with an optional interval in minutes.
        auto_topup_cycles_enable : shared (minutes : ?Nat) -> async Result.Result<Text, Text>;

        // Disables automatic top-up of cycles.
        auto_topup_cycles_disable : shared () -> async Result.Result<Text, Text>;

        // Retrieves the status of automatic top-up of cycles.
        auto_topup_cycles_status : shared query () -> async CanisterTypes.CanisterAutoTopUpDataResponse;

        // Deposits cycles into the canister.
        deposit_cycles : shared () -> async ();

        // Retrieves the current balance of cycles.
        cycles_balance : shared query () -> async Nat;
                        
    };

    /// Functions supported by the rosetta
    public type RosettaInterface = actor {
        get_transactions : shared query (GetTransactionsRequest) -> async GetTransactionsResponse;
    };

    /// Interface of the ICRC token 
    public type FullInterface = Icrc1Interface and Icrc2Interface and RosettaInterface and SlicesTokenInterface and ExtendedTokenInterface;
    

};
