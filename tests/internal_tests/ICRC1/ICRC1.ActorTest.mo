import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Float "mo:base/Float";
import Int "mo:base/Int";
import ActorSpec "../utils/ActorSpec";
import ICRC1 "../../../src/ICRC1/Modules/Token/Implementations/ICRC1.Implementation";
import T "../../../src/ICRC1/Types/Types.All";
import U "../../../src/ICRC1/Modules/Token/Utils/Utils";
import Initializer "../../../src/ICRC1/Modules/Token/Initializer/Initializer";
import TokenTypes "../../../src/ICRC1/Types/Types.Token";
import ExtendedToken "../../../src/ICRC1/Modules/Token/Implementations/EXTENDED.Implementation";
import Model "../../../src/ICRC1/Types/Types.Model";

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
            assertTrue;
            assertAllTrue;
            describe;
            it;
        } = ActorSpec;

        var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds = {
            var canisterIds = List.nil<Principal>();
        };

        let { SB } = U;

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

        let defaultModel:Model.Model = Initializer.init_model();

        return describe(
            "ICRC1 Token Implementation Tests",
            [

                it(
                    "init()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        let icrc1_standard : TokenTypes.SupportedStandard = {
                            name = "ICRC-1";
                            url = "https://github.com/dfinity/ICRC-1";
                        };

                        let icrc2_standard : TokenTypes.SupportedStandard = {
                            name = "ICRC-2";
                            url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-2";
                        };

                        // returns without trapping
                        assertAllTrue([
                            token.name == args.name,
                            token.symbol == args.symbol,
                            token.decimals == args.decimals,
                            token.defaultFee == args.fee,
                            token.max_supply == args.max_supply,

                            token.minting_account == args.minting_account,
                            SB.toArray(token.supported_standards) == [icrc1_standard, icrc2_standard],
                            SB.size(token.transactions) == 0,
                        ]);
                    },
                ),

                it(
                    "icrc1_name()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_name(token) == args.name
                        );
                    },
                ),

                it(
                    "icrc1_symbol()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_symbol(token) == args.symbol
                        );
                    },
                ),

                it(
                    "icrc1_decimals()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_decimals(token) == args.decimals
                        );
                    },
                ),
                it(
                    "icrc1_fee()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_fee(token) == args.fee
                        );
                    },
                ),
                it(
                    "icrc1_minting_account()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_minting_account(token) == args.minting_account
                        );
                    },
                ),
                it(
                    "icrc1_balance_of()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit({
                            args with initial_balances = [
                                (user1, 100),
                                (user2, 200),
                            ];
                        });

                        assertAllTrue([
                            ICRC1.icrc1_balance_of(token, user1) == 100,
                            ICRC1.icrc1_balance_of(token, user2) == 200,
                        ]);
                    },
                ),
                it(
                    "icrc1_total_supply()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit({
                            args with initial_balances = [
                                (user1, 100),
                                (user2, 200),
                            ];
                        });

                        assertTrue(
                            ICRC1.icrc1_total_supply(token) == 300
                        );
                    },
                ),

                it(
                    "icrc1_metadata()",
                    do {
                        let args = default_token_args;
                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_metadata(token) == [
                                ("icrc1:fee", #Nat(args.fee)),
                                ("icrc1:name", #Text(args.name)),
                                ("icrc1:symbol", #Text(args.symbol)),
                                ("icrc1:decimals", #Nat(Nat8.toNat(args.decimals))),
                                ("icrc1:minting_allowed", #Text(debug_show (args.minting_allowed))),
                                ("icrc1:logo", #Text(args.logo)),
                            ]
                        );
                    },
                ),

                it(
                    "icrc1_supported_standards()",
                    do {
                        let args = default_token_args;

                        let token = Initializer.tokenInit(args);

                        assertTrue(
                            ICRC1.icrc1_supported_standards(token) == [
                                {
                                    name = "ICRC-1";
                                    url = "https://github.com/dfinity/ICRC-1";
                                },
                                {
                                    name = "ICRC-2";
                                    url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-2";
                                },
                            ]
                        );
                    },
                ),

                describe(
                    "icrc1_transfer()",
                    [
                        it(
                            "Transfer from funded account",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);

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
                                    defaultModel
                                );

                                let transfer_args : TransferArgs = {
                                    from_subaccount = user1.subaccount;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.defaultFee;
                                    memo = null;
                                    created_at_time = null;
                                };

                                let res = await* ICRC1.icrc1_transfer(
                                    token,
                                    transfer_args,
                                    user1.owner,
                                    archive_canisterIds,
                                    defaultModel
                                );

                                assertAllTrue([
                                    res == #Ok(1),
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 145),
                                    token.burned_tokens == balance_from_float(token, 5),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 50),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 195),
                                ]);
                            },
                        ),
                    ],
                ),
            ],
        );
    };
};
