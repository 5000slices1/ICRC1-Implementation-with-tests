import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Random "mo:base/Random";
import Option "mo:base/Option";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import ActorSpec "../utils/ActorSpec";
import ICRC1 "../../../src/ICRC1/Modules/Token/Implementations/ICRC1.Implementation";
import T "../../../src/ICRC1/Types/Types.All";
import Initializer "../../../src/ICRC1/Modules/Token/Initializer/Initializer";
import ExtendedToken "../../../src/ICRC1/Modules/Token/Implementations/EXTENDED.Implementation";
import SlicesToken "../../../src/ICRC1/Modules/Token/Implementations/SLICES.Implementation";
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

    public func create_test_principals(numberOfPrincipals:Nat):[Principal]{

        let principals = Array.tabulate<Principal>(
        numberOfPrincipals,
        func(i) {
            Principal.fromBlob(Blob.fromArray([Nat8.fromNat(i)]));
        },
        );
        return principals;
    };

        public func create_test_accounts(numberOfAccounts:Nat):[Account]{
            let principals = Array.tabulate<Account>(
            numberOfAccounts,
            func(i) {

                {
                    owner = Principal.fromBlob(Blob.fromArray([Nat8.fromNat(i)]));
                    subaccount = null;
                };
            },
        );
        return principals;
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

        let subAccount1 : ?Blob = Option.make(await Random.blob());

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
            "Slices Token Implementation Tests",
            [

                describe(
                    "fee white listing",
                    [
                        it(
                            "Transfer with whitelist is set to transfer source principal and transfer from subaccount",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);

                                let user1WithSubaccount : Account = {
                                    owner = user1.owner;
                                    subaccount = subAccount1;
                                };

                                let mint_args = {
                                    to = user1WithSubaccount;
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

                                ignore SlicesToken.admin_add_admin_user(canister.owner, user1.owner, token);
                                ignore SlicesToken.feewhitelisting_add_principal(user1.owner, user1.owner, token);
                                let transfer_args : TransferArgs = {
                                    from_subaccount = user1WithSubaccount.subaccount;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.fee;
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
                                    ICRC1.icrc1_balance_of(token, user1WithSubaccount) == balance_from_float(token, 150),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 50),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 200),
                                ]);
                            },
                        ),
                        it(
                            "Transfer with whitelist is set to transfer source principal and transfer not from subaccount",
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

                                ignore SlicesToken.admin_add_admin_user(canister.owner, user1.owner, token);
                                ignore SlicesToken.feewhitelisting_add_principal(user1.owner, user1.owner, token);
                                let transfer_args : TransferArgs = {
                                    from_subaccount = null;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.fee;
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
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 150),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 50),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 200),
                                ]);
                            },
                        ),
                        it(
                            "Transfer with whitelist is set to transfer target principal and transfer from subaccount",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);

                                let user1WithSubaccount : Account = {
                                    owner = user1.owner;
                                    subaccount = subAccount1;
                                };

                                let mint_args = {
                                    to = user1WithSubaccount;
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

                                ignore SlicesToken.feewhitelisting_add_principal(canister.owner, user2.owner, token);
                                let transfer_args : TransferArgs = {
                                    from_subaccount = user1WithSubaccount.subaccount;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.fee;
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
                                    ICRC1.icrc1_balance_of(token, user1WithSubaccount) == balance_from_float(token, 150),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 50),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 200),
                                ]);
                            },
                        ),
                        it(
                            "Transfer with whitelist is set to transfer target principal and transfer not from subaccount",
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

                                ignore SlicesToken.feewhitelisting_add_principal(canister.owner, user2.owner, token);
                                let transfer_args : TransferArgs = {
                                    from_subaccount = null;
                                    to = user2;
                                    amount = 50 * (10 ** Nat8.toNat(token.decimals));
                                    fee = ?token.fee;
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
                                    ICRC1.icrc1_balance_of(token, user1) == balance_from_float(token, 150),
                                    token.burned_tokens == balance_from_float(token, 0),
                                    ICRC1.icrc1_balance_of(token, user2) == balance_from_float(token, 50),
                                    ICRC1.icrc1_total_supply(token) == balance_from_float(token, 200),
                                ]);
                            },
                        ),
                    ],
                ),
                describe(
                    "admin functions",
                    [
                        it(
                            "admin add user from non-admin user should fail",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);

                                let result = SlicesToken.admin_add_admin_user(user1.owner, user1.owner, token);

                                assertAllTrue([
                                    result == #err("Only owner can add admin user"),
                                ]);
                            },
                        ),
                        it(
                            "admin add user from admin user should succeed",
                            do {
                                let args = default_token_args;
                                let token = Initializer.tokenInit(args);

                                let result = SlicesToken.admin_add_admin_user(canister.owner, user1.owner, token);

                                assertAllTrue([
                                    result == #ok("Principal was added as admin user."),
                                ]);
                            },
                        ),
                    ],
                ),
                 describe(
                    "token up and down scaling",
                    [
                        it(
                            "Upscale token x100 test",
                            do {
                                let args = {default_token_args with max_supply = 1_000_000_000_000_000 * (10 ** 8);};
                                let token = Initializer.tokenInit(args);
                                
                                let testAccounts = create_test_accounts(100);
                            
                                // mint tokens for the test-accounts
                                for(i in Iter.range(0,99)){
                                    let mint_args = {
                                        to = testAccounts[i];
                                        amount = (i+100) * (10 ** Nat8.toNat(token.decimals));
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
                                };

                                let burn_args : BurnArgs = {
                                    from_subaccount = testAccounts[0].subaccount;
                                    amount = 50 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                // burn some tokens
                                let result = await* ExtendedToken.burn(token, burn_args, testAccounts[0].owner, archive_canisterIds,defaultModel);
                                                                
                                let beforeScalingMinted:Nat = ExtendedToken.minted_supply(token);
                                let beforeScalingBurned:Nat = ExtendedToken.burned_supply(token);
                                let beforeScalingMax_supply:Nat = ExtendedToken.max_supply(token);
                                let beforeScalingTotal_supply:Nat = ICRC1.icrc1_total_supply(token);
                                let beforeScalingHolders: [T.AccountTypes.AccountBalanceInfo] = SlicesToken.get_holders(token, null,null);

                                let scaleFactor:Nat = 100;                                
                                await SlicesToken.up_or_down_scale_token_directly_internal(2, true, token);
                           
                                var varExpectedHolders:List.List<T.AccountTypes.AccountBalanceInfo> = List.nil<T.AccountTypes.AccountBalanceInfo>();
                                var afterScalingTotalAmountFromAllHolders:Nat = 0;

                                for(holder in Iter.fromArray(Array.reverse(beforeScalingHolders))){

                                       let newHolder:T.AccountTypes.AccountBalanceInfo =  { holder with balance = holder.balance * scaleFactor };
                                       afterScalingTotalAmountFromAllHolders+=newHolder.balance;
                                       varExpectedHolders:=List.push<T.AccountTypes.AccountBalanceInfo>(newHolder,varExpectedHolders);    
                                };

                                let expectedAfterScalingHolders = List.toArray(varExpectedHolders);
                                let afterScalingMinted:Nat = ExtendedToken.minted_supply(token);
                                let afterScalingBurned:Nat = ExtendedToken.burned_supply(token);
                                let afterScalingMax_supply:Nat = ExtendedToken.max_supply(token);
                                let afterScalingTotal_supply:Nat = ICRC1.icrc1_total_supply(token);
                                let afterScalingHolders: [T.AccountTypes.AccountBalanceInfo] = SlicesToken.get_holders(token, null,null);

                                assertAllTrue([                                    
                                    afterScalingHolders == expectedAfterScalingHolders,
                                    afterScalingMinted == beforeScalingMinted * scaleFactor,
                                    afterScalingBurned == beforeScalingBurned * scaleFactor,
                                    afterScalingMax_supply == beforeScalingMax_supply * scaleFactor,
                                    afterScalingTotal_supply == beforeScalingTotal_supply * scaleFactor,
                                    afterScalingTotal_supply == afterScalingTotalAmountFromAllHolders                                   
                                ]);
                            },
                        ),   
                          it(
                            "Downscale token x100 test",
                            do {
                                let args = {default_token_args with max_supply = 1_000_000_000_000_000 * (10 ** 8);};
                                let token = Initializer.tokenInit(args);
                                
                                let testAccounts = create_test_accounts(100);
                            
                                // mint tokens for the test-accounts
                                for(i in Iter.range(0,99)){
                                    let mint_args = {
                                        to = testAccounts[i];
                                        amount = (i+100) * (10 ** Nat8.toNat(token.decimals));
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
                                };

                                let burn_args : BurnArgs = {
                                    from_subaccount = testAccounts[0].subaccount;
                                    amount = 50 * (10 ** Nat8.toNat(args.decimals));
                                    memo = null;
                                    created_at_time = null;
                                };

                                // burn some tokens
                                let result = await* ExtendedToken.burn(token, burn_args, testAccounts[0].owner, archive_canisterIds,defaultModel);
                                                                
                                let beforeScalingMinted:Nat = ExtendedToken.minted_supply(token);
                                let beforeScalingBurned:Nat = ExtendedToken.burned_supply(token);
                                let beforeScalingMax_supply:Nat = ExtendedToken.max_supply(token);
                                let beforeScalingTotal_supply:Nat = ICRC1.icrc1_total_supply(token);
                                let beforeScalingHolders: [T.AccountTypes.AccountBalanceInfo] = SlicesToken.get_holders(token, null,null);

                                let scaleFactor:Nat = 100;                                
                                await SlicesToken.up_or_down_scale_token_directly_internal(2, false, token);
                           
                                var varExpectedHolders:List.List<T.AccountTypes.AccountBalanceInfo> = List.nil<T.AccountTypes.AccountBalanceInfo>();
                                
                                var afterScalingTotalAmountFromAllHolders:Nat = 0;

                                for(holder in Iter.fromArray(Array.reverse(beforeScalingHolders))){

                                       let newHolder:T.AccountTypes.AccountBalanceInfo =  { holder with balance = holder.balance / scaleFactor };

                                       afterScalingTotalAmountFromAllHolders+=newHolder.balance;
                                       varExpectedHolders:=List.push<T.AccountTypes.AccountBalanceInfo>(newHolder,varExpectedHolders);    
                                };

                                let expectedAfterScalingHolders = List.toArray(varExpectedHolders);
                                let afterScalingMinted:Nat = ExtendedToken.minted_supply(token);
                                let afterScalingBurned:Nat = ExtendedToken.burned_supply(token);
                                let afterScalingMax_supply:Nat = ExtendedToken.max_supply(token);
                                let afterScalingTotal_supply:Nat = ICRC1.icrc1_total_supply(token);
                                let afterScalingHolders: [T.AccountTypes.AccountBalanceInfo] = SlicesToken.get_holders(token, null,null);

                                assertAllTrue([                                               
                                    afterScalingHolders == expectedAfterScalingHolders,
                                    afterScalingMinted == beforeScalingMinted / scaleFactor,
                                    afterScalingBurned == beforeScalingBurned / scaleFactor,
                                    afterScalingMax_supply == beforeScalingMax_supply / scaleFactor,
                                    afterScalingTotal_supply == beforeScalingTotal_supply / scaleFactor,                                
                                    afterScalingTotal_supply == afterScalingTotalAmountFromAllHolders
                                ]);
                            },
                        ),                       
                    ],
                ),
            ],
        );
    };
};
