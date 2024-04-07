module {

    ///Cycles required for initital deployment
    public let TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED : Nat = 2_900_000_000_000;

    ///Cycles needed from inside the init method
    public let TOKEN_INITIAL_CYCLES_REQUIRED : Nat = 2_000_000_000_000;

    ///The main token will only auto top-up to archive canister if main token holds at least this amount
    public let TOKEN_CYCLES_TO_KEEP : Nat = 500_000_000_000;

    ///The minimum amount of cycles needed to execute shared functions
    public let TOKEN_CYCLES_NEEDED_FOR_OPERATIONS : Nat = 500_000_000;

    ///If the archive canister holds less cycles than this amount, then it will be auto filled if auto-topup timer is enabled in token.mo
    public let ARCHIVE_CYCLES_REQUIRED : Nat = 100_000_000_000;

    //Amount of cycles to fill up
    public let ARCHIVE_CYCLES_AUTOREFILL : Nat = 400_000_000_000;

//TODO: undo
    //public let ARCHIVE_MAX_MEMORY:Nat = 10240; // approx 10 kb
    public let ARCHIVE_MAX_MEMORY:Nat = 27917287424; // approx 26 GiB
    public let ARCHIVE_MAX_HEAP_SIZE:Nat = 2018634629; // approx 1.88 GiB


    ///Number of transactions to keep in token-cache until they are transfered into archive-canister
    public let MAX_TRANSACTIONS_IN_LEDGER : Nat = 2000;
    //TODO: undo
    //public let MAX_TRANSACTIONS_IN_LEDGER:Nat = 2;

    ///The maximum number of transactions returned by request of 'get_transactions'
    public let MAX_TRANSACTIONS_PER_REQUEST : Nat = 5000;



};
