import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Float "mo:base/Float";
import Int "mo:base/Int";
import ActorSpec "../utils/ActorSpec";
import ICRC1 "../../../src/ICRC1/Modules/Token/ICRC1Token";
import T "../../../src/ICRC1/Types/Types.All";
import Initializer "../../../src/ICRC1/Modules/Token/Initializer/Initializer";
import ExtendedToken "../../../src/ICRC1/Modules/Token/ExtendedToken";
import ICRC2 "../../../src/ICRC1/Modules/Token/ICRC2Token";
import MemoryController "../../../src/ICRC1/Modules/Token/MemoryController/MemoryController";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";

// ***************************************************************************************************
// Many of these tests copied from Natlabs (and adjusted to make this work for this code-base)
// ***************************************************************************************************

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

        let user3 : Account = {
            owner = Principal.fromText("qnr6q-xmlmu-t6jhl-fyjlg-lf3fv-6mnao-oyrpr-76s4k-3lngw-jrrsd-yae");
            subaccount = null;
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

        return describe(
            "ICRC2 Token Implementation Tests",
            [

                describe(
                    "approve() & allowance()",
                    [
                        it(
                            "Approval from funded account",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance } = ICRC2.icrc2_allowance(
                                    { account = user1; spender = user2 },
                                    memoryController,
                                );

                                assertAllTrue([
                                    res == #Ok(approve_args.amount),
                                    allowance == balance_from_float(token, 50),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 195),
                                    token.burned_tokens == balance_from_float(token, 5),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 195),
                                ]);
                            },
                        ),
                        it(
                            "Approval from account with no funds",
                            do {

                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res == #Err(
                                        #InsufficientFunds { balance = 0 }
                                    ),
                                    allowance == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                ]);
                            },
                        ),
                        it(
                            "Approval from account with exact funds to pay fee",
                            do {

                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 5 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res == #Ok(approve_args.amount),
                                    allowance == balance_from_float(token, 50),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 5),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 0),
                                ]);
                            },
                        ),

                        it(
                            "Approval with correct expected allowance",
                            do {

                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 5 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = ?0;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res == #Ok(approve_args.amount),
                                    allowance == balance_from_float(token, 50),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 5),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 0),
                                ]);
                            },
                        ),

                        it(
                            "Approval with incorrect expected allowance",
                            do {

                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 5 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = ?50;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance } = ICRC2.icrc2_allowance(
                                    { account = user1; spender = user2 },
                                    memoryController,
                                );

                                assertAllTrue([
                                    res == #Err(
                                        #AllowanceChanged {
                                            current_allowance = 0;
                                        }
                                    ),
                                    allowance == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 5),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 5),
                                ]);
                            },
                        ),

                        it(
                            "Approval with expired allowance",
                            do {

                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 5 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let now = Nat64.fromNat(Int.abs(Time.now()));

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = ?(now + 100);
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res == #Err(
                                        #Expired {
                                            ledger_time = now;
                                        }
                                    ),
                                    allowance == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 5),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 5),
                                ]);
                            },
                        ),

                    ],
                ),
                describe(
                    "transfer_from()",
                    [
                        it(
                            "Spender Transfer From funded Allowance and Account",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res1 = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 20 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = await* ICRC2.icrc2_transfer_from(
                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance2 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 50)),
                                    res2 == #Ok(1),
                                    allowance1 == balance_from_float(token, 50),
                                    allowance2 == balance_from_float(token, 25),
                                    token.burned_tokens == balance_from_float(token, 10),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 170),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user3) == balance_from_float(token, 20),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 190),
                                ]);
                            },
                        ),

                        it(
                            "Spender Transfer From funded Allowance but Account with insufficient funds",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 20 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res1 = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 20 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = await* ICRC2.icrc2_transfer_from(
                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance2 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 50)),
                                    res2 == #Err(#InsufficientFunds({ balance = balance_from_float(token, 15) })),
                                    allowance1 == balance_from_float(token, 50),
                                    allowance2 == balance_from_float(token, 50),
                                    token.burned_tokens == balance_from_float(token, 5),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 15),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user3) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 15),
                                ]);
                            },
                        ),
                        it(
                            "Spender Transfer From Allowance with insufficient funds",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 20 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res1 = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 20 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = await* ICRC2.icrc2_transfer_from(

                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController

                                );

                                let {
                                    allowance = allowance2;
                                } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 20)),
                                    res2 == #Err(#InsufficientAllowance({ allowance = balance_from_float(token, 20) })),
                                    allowance1 == balance_from_float(token, 20),
                                    allowance2 == balance_from_float(token, 20),
                                    token.burned_tokens == balance_from_float(token, 5),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 45),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user3) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 45),
                                ]);
                            },
                        ),
                    ],
                ),
                describe(
                    "ICRC-2 Examples",
                    [

                        it(
                            "Alice deposits tokens to canister C",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                // 1. Alice wants to deposit 100 tokens on an ICRC-2 ledger to canister C.
                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 105 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                // 2. Alice calls icrc2_approve with spender set to the canister's default
                                // account ({ owner = C; subaccount = null}) and amount set to the token amount
                                // she wants to deposit (100) plus the transfer fee.
                                let res1 = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 3. Alice can then call some deposit method on the canister, which calls
                                // icrc2_transfer_from with from set to Alice's (the caller) account, to set to
                                // the canister's account, and amount set to the token amount she wants to deposit (100).
                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user2;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = await* ICRC2.icrc2_transfer_from(
                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController

                                );

                                // 4. The canister can now determine from the result of the call whether the transfer
                                // was successful. If it was successful, the canister can now safely commit the
                                // deposit to state and know that the tokens are in its account.

                                let {
                                    allowance = allowance2;
                                } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 105)),
                                    res2 == #Ok(1),
                                    allowance1 == balance_from_float(token, 105),
                                    allowance2 == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 10),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 90),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 100),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 190),
                                ]);
                            },
                        ),

                        it(
                            "Canister C transfers tokens from Alice's account to Bob's account, on Alice's behalf",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                // 1. Canister C wants to transfer 100 tokens on an ICRC-2 ledger from Alice's account to Bob's account.
                                let approve_args : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 105 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                // 2. Alice previously approved canister C to transfer tokens on her behalf by calling
                                // icrc2_approve with spender set to the canister's default account ({ owner = C; subaccount = null })
                                // and amount set to the token amount she wants to allow (100) plus the transfer fee.
                                let res1 = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 3. During some update call, the canister can now call icrc2_transfer_from with from set to
                                // Alice's account, to set to Bob's account, and amount set to the token amount she wants to transfer (100).
                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = await* ICRC2.icrc2_transfer_from(

                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController

                                );

                                // 4. Once the call completes successfully, Bob has 100 extra tokens on his account,
                                // and Alice has 100 (plus the fee) tokens less in her account.
                                let {
                                    allowance = allowance2;
                                } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 105)),
                                    res2 == #Ok(1),
                                    allowance1 == balance_from_float(token, 105),
                                    allowance2 == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 10),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 90),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user3) == balance_from_float(token, 100),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 190),
                                ]);
                            },
                        ),

                        it(
                            "Alice removes her allowance for canister C",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args1 : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res1 = ICRC2.icrc2_approve(
                                    user1.owner,
                                    approve_args1,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 1. Alice wants to remove her allowance of 100 tokens on an ICRC-2 ledger for canister C.

                                // 2. Alice calls icrc2_approve on the ledger with spender set to the canister's
                                // default account ({ owner = C; subaccount = null }) and amount set to 0.
                                let approve_args2 : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 0;
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = ICRC2.icrc2_approve(

                                    user1.owner,
                                    approve_args2,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance2 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 3. The canister can no longer transfer tokens on Alice's behalf.
                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res3 = await* ICRC2.icrc2_transfer_from(
                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController,
                                );

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 100)),
                                    res2 == #Ok(0),
                                    res3 == #Err(#InsufficientAllowance({ allowance = 0 })),
                                    allowance1 == balance_from_float(token, 100),
                                    allowance2 == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 10),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 190),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 190),
                                ]);
                            },
                        ),

                        it(
                            "Alice atomically removes her allowance for canister C",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args1 : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res1 = ICRC2.icrc2_approve(

                                    user1.owner,
                                    approve_args1,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 1. Alice wants to remove her allowance of 100 tokens on an ICRC-2 ledger for canister C.

                                // 2. Alice calls icrc2_approve on the ledger with spender set to the canister's default
                                // account ({ owner = C; subaccount = null }), amount set to 0, and expected_allowance set to 100 tokens.
                                let approve_args2 : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 0;
                                    expected_allowance = ?(100 * (10 ** Nat8.toNat(token.decimals)));
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = ICRC2.icrc2_approve(

                                    user1.owner,
                                    approve_args2,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance2 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 3. If the call succeeds, the allowance got removed successfully. An AllowanceChanged error
                                // would indicate that canister C used some of the allowance before Alice's call completed.
                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res3 = await* ICRC2.icrc2_transfer_from(

                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController,
                                );

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 100)),
                                    res2 == #Ok(0),
                                    res3 == #Err(#InsufficientAllowance({ allowance = 0 })),
                                    allowance1 == balance_from_float(token, 100),
                                    allowance2 == balance_from_float(token, 0),
                                    token.burned_tokens == balance_from_float(token, 10),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 190),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 190),
                                ]);
                            },
                        ),

                        it(
                            "Alice atomically removes her allowance for canister C - AllowanceChanged",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);
                                let model = Initializer.init_model();
                                let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

                                let mint_args = {
                                    to = user1;
                                    amount = 200 * (10 ** Nat8.toNat(token.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                ignore await* ExtendedToken.mint(
                                    token,
                                    mint_args,
                                    args.minting_account.owner,
                                    archive_canisterIds,
                                );

                                let approve_args1 : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 100 * (10 ** Nat8.toNat(token.decimals));
                                    expected_allowance = null;
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res1 = ICRC2.icrc2_approve(

                                    user1.owner,
                                    approve_args1,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance1 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // Adds transfer to check for AllowanceChanged
                                let transfer_from_args : T.TransactionTypes.TransferFromArgs = {
                                    spender_subaccount = user2.subaccount;
                                    from = user1;
                                    to = user3;
                                    amount = 10 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res2 = await* ICRC2.icrc2_transfer_from(

                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController,
                                );

                                let { allowance = allowance2 } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 1. Alice wants to remove her allowance of 100 tokens on an ICRC-2 ledger for canister C.

                                // 2. Alice calls icrc2_approve on the ledger with spender set to the canister's default
                                // account ({ owner = C; subaccount = null }), amount set to 0, and expected_allowance set to 100 tokens.
                                let approve_args2 : T.TransactionTypes.ApproveArgs = {
                                    from_subaccount = user1.subaccount;
                                    spender = user2;
                                    amount = 0;
                                    expected_allowance = ?(100 * (10 ** Nat8.toNat(token.decimals)));
                                    expires_at = null;
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res3 = ICRC2.icrc2_approve(

                                    user1.owner,
                                    approve_args2,
                                    token,
                                    memoryController

                                );

                                let {
                                    allowance = allowance3;
                                } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                // 3. If the call succeeds, the allowance got removed successfully. An AllowanceChanged error
                                // would indicate that canister C used some of the allowance before Alice's call completed.
                                let res4 = await* ICRC2.icrc2_transfer_from(

                                    user2.owner,
                                    transfer_from_args,
                                    token,
                                    memoryController

                                );

                                let {
                                    allowance = allowance4;
                                } = ICRC2.icrc2_allowance({ account = user1; spender = user2 }, memoryController);

                                assertAllTrue([
                                    res1 == #Ok(balance_from_float(token, 100)),
                                    res2 == #Ok(1),
                                    res3 == #Err(#AllowanceChanged({ current_allowance = balance_from_float(token, 85) })),
                                    res4 == #Ok(2),
                                    allowance1 == balance_from_float(token, 100),
                                    allowance2 == balance_from_float(token, 85),
                                    allowance3 == balance_from_float(token, 85),
                                    allowance4 == balance_from_float(token, 70),
                                    token.burned_tokens == balance_from_float(token, 15),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 165),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user3) == balance_from_float(token, 20),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 185),
                                ]);
                            },
                        ),
                    ],
                ),
            ],
        );
    };
};
