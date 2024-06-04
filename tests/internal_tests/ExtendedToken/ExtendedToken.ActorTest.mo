import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Itertools "mo:itertools/Iter";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import ActorSpec "../utils/ActorSpec";
import ICRC1 "../../../src/ICRC1/Modules/Token/Implementations/ICRC1.Implementation";
import T "../../../src/ICRC1/Types/Types.All";
import U "../../../src/ICRC1/Modules/Token/Utils/Utils";
import ExtendedToken "../../../src/ICRC1/Modules/Token/Implementations/EXTENDED.Implementation";
import Initializer "../../../src/ICRC1/Modules/Token/Initializer/Initializer";
import Model "../../../src/ICRC1/Types/Types.Model";
import MemoryController "../../../src/ICRC1/Modules/Token/MemoryController/MemoryController";
import TypesBackupRestore "../../../src/ICRC1/Types/Types.BackupRestore";
import SlicesImplementation "../../../src/ICRC1/Modules/Token/Implementations/SLICES.Implementation";

module {

    private type Balance = T.Balance;
    private type Account = T.AccountTypes.Account;
    private type TokenData = T.TokenTypes.TokenData;
    private type InitArgs = T.TokenTypes.InitArgs;
    private type Transaction = T.TransactionTypes.Transaction;
    private type GetTransactionsRequest = T.TransactionTypes.GetTransactionsRequest;
    private type GetTransactionsResponse = T.TransactionTypes.GetTransactionsResponse;
    private type ArchivedTransaction = T.TransactionTypes.ArchivedTransaction;
    private type Mint = T.TransactionTypes.Mint;
    private type BurnArgs = T.TransactionTypes.BurnArgs;
    private type TransferArgs = T.TransactionTypes.TransferArgs;

    /// Formats a float to a nat balance and applies the correct number of decimal places
    public func balance_from_float(token : TokenData, float : Float) : Balance {
        if (float <= 0) {
            return 0;
        };

        let float_with_decimals = float * (10 ** Float.fromInt(Nat8.toNat(token.decimals)));

        Int.abs(Float.toInt(float_with_decimals));
    };

    public func test() : async ActorSpec.Group {

        let {
            assertAllTrue;
            describe;
            it;
        } = ActorSpec;

        var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds = {
            var canisterIds = List.nil<Principal>();
        };

        let { SB } = U;

        func create_test_accounts(numberOfAccounts : Nat) : [Account] {

            let bufferNat8Array = Buffer.Buffer<Nat8>(1);
            let principals = Array.tabulate<Account>(
                numberOfAccounts,
                func(i) {

                    var num : Nat = i + 8191;
                    bufferNat8Array.clear();
                    var complete : Bool = false;
                    while (complete == false) {
                        let numberToTake = num % 128;

                        bufferNat8Array.add(Nat8.fromNat(numberToTake));
                        num := num / 128;
                        if (num <= 0) {
                            complete := true;
                        };
                    };

                    let account : Account = {
                        owner = Principal.fromBlob(Blob.fromArray(Buffer.toArray(bufferNat8Array)));
                        subaccount = null;
                    };
                    return account;
                },
            );
            return principals;
        };

        func mock_tx(to : Account, index : Nat, fee : Nat) : Transaction {
            {
                burn = null;
                transfer = null;
                kind = "MINT";
                timestamp = 0;
                index;
                mint = ?{
                    to;
                    amount = (index + 1) + fee;
                    memo = null;
                    created_at_time = null;
                };
            };
        };

        let canister : Account = {
            owner = Principal.fromText("x4ocp-k7ot7-oiqws-rg7if-j4q2v-ewcel-2x6we-l2eqz-rfz3e-6di6e-jae");
            subaccount = null;
        };

        let user1 : Account = {
            owner = Principal.fromText("prb4z-5pc7u-zdfqi-cgv7o-fdyqf-n6afm-xh6hz-v4bk4-kpg3y-rvgxf-iae");
            subaccount = null;
        };

        let user2 : Account = {
            owner = Principal.fromText("ygyq4-mf2rf-qmcou-h24oc-qwqvv-gt6lp-ifvxd-zaw3i-celt7-blnoc-5ae");
            subaccount = null;
        };

        func txs_range(start : Nat, end : Nat, fee : Nat) : [Transaction] {
            Array.tabulate(
                (end - start) : Nat,
                func(i : Nat) : Transaction {
                    mock_tx(user1, start + i, fee);
                },
            );
        };

        func is_tx_equal(t1 : Transaction, t2 : Transaction) : Bool {
            { t1 with timestamp = 0 } == { t2 with timestamp = 0 };
        };

        func is_opt_tx_equal(t1 : ?Transaction, t2 : ?Transaction) : Bool {
            switch (t1, t2) {
                case (?t1, ?t2) {
                    is_tx_equal(t1, t2);
                };
                case (_, ?t2) { false };
                case (?t1, _) { false };
                case (_, _) { true };
            };
        };

        func validate_get_transactions(
            token : TokenData,
            tx_req : GetTransactionsRequest,
            tx_res : GetTransactionsResponse,
        ) : Bool {
            let { archive } = token;

            let token_start = 0;
            let token_end = ExtendedToken.total_transactions(token);

            let req_start = tx_req.start;
            let req_end = tx_req.start + tx_req.length;

            var log_length = 0;

            if (req_start < token_end) {
                log_length := (Nat.min(token_end, req_end) - Nat.max(token_start, req_start)) : Nat;
            };

            if (log_length != tx_res.log_length) {
                Debug.print("Failed at log_length: " # Nat.toText(log_length) # " != " # Nat.toText(tx_res.log_length));
                return false;
            };

            var txs_size = 0;
            if (req_end > archive.stored_txs and req_start <= token_end) {
                txs_size := Nat.min(req_end, token_end) - archive.stored_txs;
            };

            if (txs_size != tx_res.transactions.size()) {
                Debug.print("Failed at txs_size: " # Nat.toText(txs_size) # " != " # Nat.toText(tx_res.transactions.size()));
                return false;
            };

            if (txs_size > 0) {
                let index = tx_res.transactions[0].index;

                if (tx_res.first_index != index) {
                    Debug.print("Failed at first_index: " # Nat.toText(tx_res.first_index) # " != " # Nat.toText(index));
                    return false;
                };

                for (i in Iter.range(0, txs_size - 1)) {
                    let tx = tx_res.transactions[i];
                    let mocked_tx = mock_tx(user1, archive.stored_txs + i, token.defaultFee);

                    if (not is_tx_equal(tx, mocked_tx)) {

                        Debug.print("Failed at tx: " # debug_show (tx) # " != " # debug_show (mocked_tx));
                        return false;
                    };
                };
            } else {
                if (tx_res.first_index != 0xFFFF_FFFF_FFFF_FFFF) {
                    Debug.print("Failed at first_index: " # Nat.toText(tx_res.first_index) # " != " # Nat.toText(0xFFFF_FFFF_FFFF_FFFF));
                    return false;
                };
            };

            true;
        };

        func validate_archived_range(request : [GetTransactionsRequest], response : [ArchivedTransaction], fee : Nat) : async Bool {

            if (request.size() != response.size()) {
                return false;
            };

            for ((req, res) in Itertools.zip(request.vals(), response.vals())) {
                if (res.start != req.start) {
                    Debug.print("Failed at start: " # Nat.toText(res.start) # " != " # Nat.toText(req.start));
                    return false;
                };
                if (res.length != req.length) {
                    Debug.print("Failed at length: " # Nat.toText(res.length) # " != " # Nat.toText(req.length));
                    return false;
                };

                let archived_txs = (await res.callback(req)).transactions;
                let expected_txs = txs_range(res.start, res.start + res.length, fee);

                if (archived_txs.size() != expected_txs.size()) {
                    return false;
                };

                for ((tx1, tx2) in Itertools.zip(archived_txs.vals(), expected_txs.vals())) {
                    if (not is_tx_equal(tx1, tx2)) {
                        Debug.print("Failed at archived_txs: " # debug_show (tx1, tx2));
                        return false;
                    };
                };

            };

            true;
        };

        func create_mints(token : TokenData, minting_principal : Principal, n : Nat, model : Model.Model) : async () {
            for (i in Itertools.range(0, n)) {
                var res = await* ExtendedToken.mint(
                    token,
                    {
                        to = user1;
                        amount = (i + 1) + token.defaultFee;
                        memo = null;
                        created_at_time = null;
                    },
                    minting_principal,
                    archive_canisterIds,
                    model,
                );
            };
        };

        let default_token_args : InitArgs = {
            name = "Under-Collaterised Lending Tokens";
            symbol = "UCLTs";
            decimals = 8;
            fee = 5 * (10 ** 8);
            max_supply = 1_000_000_000 * (10 ** 8);
            minting_account = canister;
            initial_balances = [];
            logo = "";
            min_burn_amount = (10 * (10 ** 8));
            advanced_settings = null;
            minting_allowed = true;
        };

        let defaultModel : Model.Model = Initializer.init_model();

        return describe(
            "Extended Token Implementation Tests",
            [

                it(
                    "mint() with minting allowed",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        let mint_args : Mint = {
                            to = user1;
                            amount = 200 * (10 ** Nat8.toNat(args.decimals));
                            memo = null;
                            created_at_time = null;
                        };

                        let res = await* ExtendedToken.mint(
                            token,
                            mint_args,
                            args.minting_account.owner,
                            archive_canisterIds,
                            defaultModel,
                        );

                        assertAllTrue([
                            res == #Ok(0),
                            ICRC1.icrc1_balance_of(token, user1) == mint_args.amount,
                            ICRC1.icrc1_balance_of(token, args.minting_account) == 0,
                            ICRC1.icrc1_total_supply(token) == mint_args.amount,
                        ]);
                    },
                ),
                it(
                    "mint() with minting not allowed",
                    do {

                        let args : InitArgs = {
                            default_token_args with minting_allowed = false
                        };

                        let token = Initializer.tokenInit(args);

                        let mint_args : Mint = {
                            to = user1;
                            amount = 200 * (10 ** Nat8.toNat(args.decimals));
                            memo = null;
                            created_at_time = null;
                        };

                        let res = await* ExtendedToken.mint(
                            token,
                            mint_args,
                            args.minting_account.owner,
                            archive_canisterIds,
                            defaultModel,
                        );

                        assertAllTrue([
                            res == #Err(
                                #GenericError {
                                    error_code = 401;
                                    message = "Error: Minting not allowed for this token.";
                                }
                            ),
                            ICRC1.icrc1_balance_of(token, user1) == 0,
                            ICRC1.icrc1_balance_of(token, args.minting_account) == 0,
                            ICRC1.icrc1_total_supply(token) == 0,
                        ]);
                    },
                ),

                describe(
                    "burn()",
                    [
                        it(
                            "from funded account",
                            do {
                                let args = default_token_args;

                                let token = Initializer.tokenInit(args);

                                let mint_args : Mint = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                    defaultModel,
                                );

                                let burn_args : BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = 50 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                let prev_balance = ICRC1.icrc1_balance_of(token, user1);
                                let prev_total_supply = ICRC1.icrc1_total_supply(token);

                                let res = await* ExtendedToken.burn(token, burn_args, user1.owner, archive_canisterIds, defaultModel);

                                assertAllTrue([
                                    res == #Ok(1),
                                    ICRC1.icrc1_balance_of(token, user1) == ((prev_balance - burn_args.amount) : Nat),
                                    ICRC1.icrc1_total_supply(token) == ((prev_total_supply - burn_args.amount) : Nat),
                                ]);
                            },
                        ),
                        it(
                            "from an empty account",
                            do {
                                let args = default_token_args;

                                let token = Initializer.tokenInit(args);

                                let burn_args : BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = await* ExtendedToken.burn(token, burn_args, user1.owner, archive_canisterIds, defaultModel);

                                assertAllTrue([
                                    res == #Err(
                                        #InsufficientFunds {
                                            balance = 0;
                                        }
                                    ),
                                ]);
                            },
                        ),
                        it(
                            "burn amount less than min_burn_amount",
                            do {
                                let args = default_token_args;

                                let token = Initializer.tokenInit(args);

                                let mint_args : Mint = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                    defaultModel,
                                );

                                let burn_args : BurnArgs = {
                                    from_subaccount = user1.subaccount;
                                    amount = args.min_burn_amount - 10;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = await* ExtendedToken.burn(token, burn_args, user1.owner, archive_canisterIds, defaultModel);
                                assertAllTrue([
                                    res == #Err(#BadBurn({ min_burn_amount = args.min_burn_amount }))
                                ]);
                            },
                        ),
                    ],
                ),

                describe(
                    "Internal Archive Testing",
                    [
                        describe(
                            "A token canister with 4123 total txs",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);

                                await create_mints(token, canister.owner, 4123, defaultModel);
                                [
                                    it(
                                        "Archive has 4000 stored txs",
                                        do {

                                            assertAllTrue([
                                                token.archive.stored_txs == 4000,
                                                SB.size(token.transactions) == 123,
                                                SB.capacity(token.transactions) == T.ConstantTypes.MAX_TRANSACTIONS_IN_LEDGER,
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transaction() works for txs in the archive and ledger canister",
                                        do {

                                            assertAllTrue([
                                                is_opt_tx_equal(
                                                    (await* ExtendedToken.get_transaction(token, 0)),
                                                    ?mock_tx(user1, 0, token.defaultFee),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ExtendedToken.get_transaction(token, 1234)),
                                                    ?mock_tx(user1, 1234, token.defaultFee),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ExtendedToken.get_transaction(token, 2000)),
                                                    ?mock_tx(user1, 2000, token.defaultFee),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ExtendedToken.get_transaction(token, 4100)),
                                                    ?mock_tx(user1, 4100, token.defaultFee),
                                                ),
                                                is_opt_tx_equal(
                                                    (await* ExtendedToken.get_transaction(token, 4122)),
                                                    ?mock_tx(user1, 4122, token.defaultFee),
                                                ),
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions from 0 to 2000",
                                        do {
                                            let req = {
                                                start = 0;
                                                length = 2000;
                                            };

                                            let res = ExtendedToken.get_transactions(
                                                token,
                                                req,
                                            );

                                            let archived_txs = res.archived_transactions;

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                (await validate_archived_range([{ start = 0; length = 2000 }], archived_txs, token.defaultFee)),
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions from 3000 to 4123",
                                        do {
                                            let req = {
                                                start = 3000;
                                                length = 1123;
                                            };

                                            let res = ExtendedToken.get_transactions(
                                                token,
                                                req,
                                            );

                                            let archived_txs = res.archived_transactions;

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                (await validate_archived_range([{ start = 3000; length = 1000 }], archived_txs, token.defaultFee)),
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions from 4000 to 4123",
                                        do {
                                            let req = {
                                                start = 4000;
                                                length = 123;
                                            };

                                            let res = ExtendedToken.get_transactions(
                                                token,
                                                req,
                                            );

                                            let archived_txs = res.archived_transactions;

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                (await validate_archived_range([], archived_txs, token.defaultFee)),
                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions exceeding the txs in the ledger (0 to 5000)",
                                        do {
                                            let req = {
                                                start = 0;
                                                length = 5000;
                                            };

                                            let res = ExtendedToken.get_transactions(
                                                token,
                                                req,
                                            );

                                            let archived_txs = res.archived_transactions;

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                (await validate_archived_range([{ start = 0; length = 4000 }], archived_txs, token.defaultFee)),

                                            ]);
                                        },
                                    ),
                                    it(
                                        "get_transactions outside the txs range (5000 to 6000)",
                                        do {
                                            let req = {
                                                start = 5000;
                                                length = 1000;
                                            };

                                            let res = ExtendedToken.get_transactions(
                                                token,
                                                req,
                                            );

                                            let archived_txs = res.archived_transactions;

                                            assertAllTrue([
                                                validate_get_transactions(token, req, res),
                                                (await validate_archived_range([], archived_txs, token.defaultFee)),

                                            ]);
                                        },
                                    ),
                                ];
                            },
                        ),
                    ],
                ),

                describe(
                    "backup() and restore()",
                    [
                        it(
                            "backup and restore Token common data",
                            do {
                                let args = default_token_args;

                                let token : T.TokenTypes.TokenData = Initializer.tokenInit(args);
                                let token_clone : T.TokenTypes.TokenData = Initializer.tokenInit(args);

                                let model : Model.Model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let backupParameter : TypesBackupRestore.BackupParameter = {
                                    backupType : TypesBackupRestore.BackupType = #tokenCommonData;
                                    currentIndex : ?Nat = null;
                                    chunkCount : ?Nat = null;
                                };

                                // get backup from token main data
                                let backupResult : Result.Result<(isComplete : Bool, data : [Nat8]), Text> = ExtendedToken.backup(memoryController, token, backupParameter);

                                var failed : Bool = false;
                                var dataArray : [Nat8] = [];
                                switch (backupResult) {
                                    case (#ok(isComplete : Bool, data : [Nat8])) {

                                        dataArray := data;
                                    };
                                    case (#err(text)) {
                                        failed := true;
                                        Debug.print("Error. Could not serialize token main data");
                                    };
                                };

                                // change token data
                                if (failed == false) {
                                    token.name := "Noname";
                                    token.symbol := "newSymbol";
                                    token.decimals := 2;
                                    token.defaultFee := 1234;
                                    token.logo := "MyLogo";
                                    token.max_supply := 10000;
                                    token.minted_tokens := 222;
                                    token.minting_allowed := false;
                                    token.burned_tokens := 123;
                                    token.minting_account := user2;
                                    SB.clear(token.supported_standards);
                                    token.transaction_window := 222;
                                    token.min_burn_amount := 2;
                                    token.permitted_drift := 1000;

                                    ignore SlicesImplementation.admin_add_admin_user(canister.owner, user2.owner, token);
                                    ignore SlicesImplementation.feewhitelisting_add_principal(canister.owner, user2.owner, token);
                                };

                                // restore from backup
                                if (failed == false) {
                                    let restoreInfo : TypesBackupRestore.RestoreInfo = {
                                        dataType = #tokenCommonData;
                                        isFirstChunk = true;
                                        bytes = dataArray;
                                    };
                                    let result : Result.Result<Text, Text> = ExtendedToken.restore(memoryController, token, restoreInfo);

                                    switch (result) {
                                        case (#ok(value)) {
                                            // do nothing
                                        };
                                        case (#err(error)) {
                                            failed := true;
                                        };
                                    };
                                };

                                assertAllTrue([
                                    failed == false,
                                    token.name == token_clone.name,
                                    token.symbol == token_clone.symbol,
                                    token.decimals == token_clone.decimals,
                                    token.defaultFee == token_clone.defaultFee,
                                    token.logo == token_clone.logo,
                                    token.max_supply == token_clone.max_supply,
                                    token.minted_tokens == token_clone.minted_tokens,
                                    token.minting_allowed == token_clone.minting_allowed,
                                    token.burned_tokens == token_clone.burned_tokens,
                                    token.minting_account == token_clone.minting_account,
                                    SB.toArray(token.supported_standards) == SB.toArray(token_clone.supported_standards),
                                    token.transaction_window == token_clone.transaction_window,
                                    token.min_burn_amount == token_clone.min_burn_amount,
                                    token.permitted_drift == token_clone.permitted_drift,
                                    SlicesImplementation.feewhitelisting_get_list(token) == SlicesImplementation.feewhitelisting_get_list(token_clone),
                                    SlicesImplementation.list_admin_users(token) == SlicesImplementation.list_admin_users(token_clone),

                                ]);

                            },
                        ),
                        it(
                            "backup and restore accounts",
                            do {

                                let args = {
                                    default_token_args with max_supply = 1_000_000_000_000_000 * (10 ** 8)
                                };

                                let token : T.TokenTypes.TokenData = Initializer.tokenInit(args);
                                let token_clone : T.TokenTypes.TokenData = Initializer.tokenInit(args);

                                let model : Model.Model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                // create many accounts
                                let manyAccounts : [Account] = create_test_accounts(7000);

                                // mint some tokens

                                let mint_args : Mint = {
                                    to = user1;
                                    amount = 100_000_000 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                    defaultModel,
                                );

                                ignore await* ExtendedToken.mint(
                                    token_clone,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                    defaultModel,
                                );

                                // Add some transactions

                                for (i in Iter.range(0, 5200)) {
                                    let account = manyAccounts[i];

                                    let transfer_args : TransferArgs = {
                                        from_subaccount = user1.subaccount;
                                        to = account;
                                        amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                        fee = ?token.defaultFee;
                                        memo = null;
                                        created_at_time = null;
                                    };
                                    ignore await* ICRC1.icrc1_transfer(
                                        token,
                                        transfer_args,
                                        user1.owner,
                                        archive_canisterIds,
                                        defaultModel,
                                    );

                                    ignore await* ICRC1.icrc1_transfer(
                                        token_clone,
                                        transfer_args,
                                        user1.owner,
                                        archive_canisterIds,
                                        defaultModel,
                                    );
                                };

                                let holdersCount = SlicesImplementation.get_holders_count(token);
                                var batchSize = 100;
                                let batchCount = holdersCount / batchSize;

                                // -----------------------------------------------------------------------
                                // Create backup
                                var backupComplete = false;
                                var index = 0;

                                let bufferNat8Array = Buffer.Buffer<[Nat8]>(batchCount);
                                var failed : Bool = false;
                                var counter = 0;
                                while (backupComplete == false) {

                                    //Debug.print("counter = " # debug_show(counter));
                                    counter += 1;

                                    let backupParameter : TypesBackupRestore.BackupParameter = {
                                        backupType : TypesBackupRestore.BackupType = #tokenAccounts;
                                        currentIndex : ?Nat = Option.make(index);
                                        chunkCount : ?Nat = ?batchSize;
                                    };

                                    let backupResult : Result.Result<(isComplete : Bool, data : [Nat8]), Text> = ExtendedToken.backup(memoryController, token, backupParameter);

                                    switch (backupResult) {
                                        case (#ok(isComplete, data)) {
                                            bufferNat8Array.add(data);
                                            if (isComplete == true) {
                                                backupComplete := true;
                                            };
                                        };
                                        case (#err(text)) {
                                            Debug.print("Error. Could not serialize token main data");
                                            Debug.print("Error text = " #text);
                                            backupComplete := true;
                                            failed := true;
                                        };
                                    };
                                    index := index + batchSize;
                                };

                                // -----------------------------------------------------------------------

                                // change token data
                                if (failed == false) {

                                    // Create some more transactions
                                    // These additional transactions should be undone after restoring is complete.(This is the test)

                                    for (account in Iter.fromArray(manyAccounts)) {

                                        let transfer_args : TransferArgs = {
                                            from_subaccount = user1.subaccount;
                                            to = account;
                                            amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                            fee = ?token.defaultFee;
                                            memo = null;
                                            created_at_time = null;
                                        };
                                        ignore await* ICRC1.icrc1_transfer(
                                            token,
                                            transfer_args,
                                            user1.owner,
                                            archive_canisterIds,
                                            defaultModel,
                                        );
                                    };
                                };

                                let isEqualBefore =  SlicesImplementation.get_holders(token, null, null) == SlicesImplementation.get_holders(token_clone, null, null);

                                // restore from backup
                                if (failed == false) {

                                    var isFirst = true;
                                    Buffer.iterate<[Nat8]>(
                                        bufferNat8Array,
                                        func(x) {

                                            let restoreInfo : TypesBackupRestore.RestoreInfo = {
                                                dataType = #tokenAccounts;
                                                isFirstChunk = isFirst;
                                                bytes = x;
                                            };
                                            ignore ExtendedToken.restore(memoryController, token, restoreInfo);
                                            isFirst := false;
                                        },
                                    );
                                };

                                let isEqualAfter =  SlicesImplementation.get_holders(token, null, null) == SlicesImplementation.get_holders(token_clone, null, null);

                                assertAllTrue([
                                    failed == false,
                                    isEqualBefore == false,
                                    isEqualAfter == true                                    
                                ]);

                            },
                        ),


                        it(
                            "backup and restore transaction buffer",
                            do {

                                let args = {
                                    default_token_args with max_supply = 1_000_000_000_000_000 * (10 ** 8)
                                };

                                let token : T.TokenTypes.TokenData = Initializer.tokenInit(args);
                                let token_clone : T.TokenTypes.TokenData = Initializer.tokenInit(args);

                                let model : Model.Model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                // create many accounts
                                let manyAccounts : [Account] = create_test_accounts(3000);

                                // mint some tokens

                                let mint_args : Mint = {
                                    to = user1;
                                    amount = 100_000_000 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                    defaultModel,
                                );

                                ignore await* ExtendedToken.mint(
                                    token_clone,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                    defaultModel,
                                );

                                // Add some transactions

                                for (i in Iter.range(0, 1898)) {
                                    let account = manyAccounts[i];

                                    let transfer_args : TransferArgs = {
                                        from_subaccount = user1.subaccount;
                                        to = account;
                                        amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                        fee = ?token.defaultFee;
                                        memo = null;
                                        created_at_time = null;
                                    };
                                    ignore await* ICRC1.icrc1_transfer(
                                        token,
                                        transfer_args,
                                        user1.owner,
                                        archive_canisterIds,
                                        defaultModel,
                                    );

                                    ignore await* ICRC1.icrc1_transfer(
                                        token_clone,
                                        transfer_args,
                                        user1.owner,
                                        archive_canisterIds,
                                        defaultModel,
                                    );
                                };
                             
                                var failed = false;
                                // -----------------------------------------------------------------------
                                // Create backup


                                let backupParameter : TypesBackupRestore.BackupParameter = {
                                        backupType : TypesBackupRestore.BackupType = #tokenTransactionsBuffer;
                                        currentIndex : ?Nat = null;
                                        chunkCount : ?Nat = null;
                                };

                                let backupResult : Result.Result<(isComplete : Bool, data : [Nat8]), Text> = 
                                    ExtendedToken.backup(memoryController, token, backupParameter);
                                
                                var nat8Array:[Nat8] = [];

                                switch(backupResult){
                                    case (#ok(isComplete, dataArray)){
                                        nat8Array:=dataArray;
                                    };
                                    case (#err(text)){
                                        failed:=true;
                                    };

                                };
                                
                                // -----------------------------------------------------------------------

                                // change token data
                                if (failed == false) {

                                    // Create some more transactions
                                    // These additional transactions should be undone after restoring is complete.(This is the test)

                                    for (m in Iter.range(2000,2300)) {

                                        let accountItem = manyAccounts[m];

                                        let transfer_args : TransferArgs = {
                                            from_subaccount = user1.subaccount;
                                            to = accountItem;
                                            amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                            fee = ?token.defaultFee;
                                            memo = null;
                                            created_at_time = null;
                                        };
                                        ignore await* ICRC1.icrc1_transfer(
                                            token,
                                            transfer_args,
                                            user1.owner,
                                            archive_canisterIds,
                                            defaultModel,
                                        );
                                    };
                                };

                                let isEqualBefore = SB.toArray(token.transactions) == SB.toArray(token_clone.transactions);

                                // restore from backup
                                if (failed == false) {

                                    let restoreInfo : TypesBackupRestore.RestoreInfo = {
                                                dataType = #tokenTransactionsBuffer;
                                                isFirstChunk = true;
                                                bytes = nat8Array;
                                            };
                                    let res = ExtendedToken.restore(memoryController, token, restoreInfo);                                    
                                };
                                
                                let isEqualAfter = SB.toArray(token.transactions) == SB.toArray(token_clone.transactions);
                          
                                assertAllTrue([
                                    failed == false,
                                    isEqualBefore == false,
                                    isEqualAfter == true
                                ]);

                            },
                        ),
                    ],
                ),
            ],
        );
    };
};
