import Result "mo:base/Result";

import ICRC1 "../../src";

shared({ caller = _owner }) actor class Token(
    _name: Text,
    _symbol: Text,
    _decimals : Nat8,
    _fee: ICRC1.Balance,
    _minting_account : ICRC1.Account,
    _max_supply : ICRC1.Balance,
    _store_transactions: Bool,
) : async ICRC1.Interface {

    let token = ICRC1.init({
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        fee = _fee;
        minting_account = _minting_account;
        max_supply = _max_supply;
        store_transactions = _store_transactions;
    });

    public shared query func icrc1_name() : async Text {
        ICRC1.name(token)
    };

    public shared query func icrc1_symbol() : async Text {
        ICRC1.symbol(token)
    };

    public shared query func icrc1_decimals() : async Nat8 {
        ICRC1.decimals(token)
    };

    public shared query func icrc1_fee() : async ICRC1.Balance {
        ICRC1.fee(token)
    };

    public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
        ICRC1.metadata(token)
    };

    public shared query func icrc1_total_supply() : async ICRC1.Balance {
        ICRC1.total_supply(token)
    };

    public shared query func icrc1_minting_account() : async ?ICRC1.Account {
        ?ICRC1.minting_account(token)
    };

    public shared query func icrc1_balance_of(args: ICRC1.Account) : async ICRC1.Balance {
        ICRC1.balance_of(token, args)
    };

    public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
        ICRC1.supported_standards(token)
    };

    public shared({ caller }) func icrc1_transfer(args: ICRC1.TransferArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        ICRC1.transfer(token, args, caller)
    };

    public shared({ caller }) func mint(args: ICRC1.MintArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        ICRC1.mint(token, args, caller)
    };

    public shared({ caller }) func burn(args: ICRC1.BurnArgs) : async Result.Result<ICRC1.Balance, ICRC1.TransferError> {
        ICRC1.burn(token, args, caller)
    };
};