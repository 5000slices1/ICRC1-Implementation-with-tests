import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Itertools "mo:itertools/Iter";
import STMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";
import Account "../Account/Account";
import CommonTypes "../../../Types/Types.Common";
import TokenTypes "../../../Types/Types.Token";
import AccountTypes "../../../Types/Types.Account";
import TransactionTypes "../../../Types/Types.Transaction";
import List "mo:base/List";

module {

    //Common types
    private type Balance = CommonTypes.Balance;

    //Token types
    private type InitArgs = TokenTypes.InitArgs;
    private type MetaDatum = TokenTypes.MetaDatum;
    private type SupportedStandard = CommonTypes.SupportedStandard;
    private type TokenData = TokenTypes.TokenData;

    //Account types
    private type Subaccount = AccountTypes.Subaccount;
    private type AccountBalances = AccountTypes.AccountBalances;
    private type EncodedAccount = AccountTypes.EncodedAccount;

    //Transaction types
    private type TransferArgs = TransactionTypes.TransferArgs;
    private type TxKind = TransactionTypes.TxKind;
    private type TransactionRequest = TransactionTypes.TransactionRequest;
    private type Transaction = TransactionTypes.Transaction;

    /// this is a local copy of deprecated Hash.hashNat8 (redefined to suppress the warning)
    func hashNat8(key : [Nat32]) : Hash.Hash {
        var hash : Nat32 = 0;
        for (natOfKey in key.vals()) {
            hash := hash +% natOfKey;
            hash := hash +% hash << 10;
            hash := hash ^ (hash >> 6);
        };
        hash := hash +% hash << 3;
        hash := hash ^ (hash >> 11);
        hash := hash +% hash << 15;
        return hash;
    };

    /// Computes a hash from the least significant 32-bits of `n`, ignoring other bits.
    public func hash(n : Nat) : Hash.Hash {
        let j = Nat32.fromNat(n);
        hashNat8([
            j & (255 << 0),
            j & (255 << 8),
            j & (255 << 16),
            j & (255 << 24),
        ]);
    };

    // Return defaultFee or if principalfrom/principalTo is fee whitelisted then 0 is returned.
    public func get_real_token_fee(
        principalFrom : Principal,
        principalTo : Principal,
        token : TokenData,
    ) : Balance {

        let listSize : Nat = List.size<Principal>(token.feeWhitelistedPrincipals);
        if (listSize == 0) {
            return token.fee;
        };

        func listFindFunc(x : Principal) : Bool {
            x == principalFrom or x == principalTo;
        };

        let isWhitelisted : Bool = List.some<Principal>(
            token.feeWhitelistedPrincipals,
            listFindFunc,
        );

        if (isWhitelisted == true) {
            return 0;
        };

        return token.fee;

    };

    public func get_real_token_fee_with_specified_defaultFee(
        principalFrom : Principal,
        principalTo : Principal,
        token : TokenData,
        feeSpecified : ?Balance,
    ) : Balance {

        var result : Balance = get_real_token_fee(principalFrom, principalTo, token);
        switch (feeSpecified) {
            case (?feeValue) {
                if (result > 0) {
                    result := Nat.max(feeValue, result);
                };
                return result;

            };
            case (_) { return token.fee };
        };

    };

    /// Formats the different operation arguments into
    /// a `TransactionRequest`, an internal type to access fields easier.
    public func create_transfer_req(
        args : TransferArgs,
        owner : Principal,
        tx_kind : TxKind,
        token : TokenData,
    ) : TransactionRequest {

        var transferFee = get_real_token_fee_with_specified_defaultFee(owner, args.to.owner, token, args.fee);

        let from = {
            owner;
            subaccount = args.from_subaccount;
        };

        let encoded = {
            from = Account.encode(from);
            to = Account.encode(args.to);
        };

        switch (tx_kind) {
            case (#mint) {
                {
                    args with kind = #mint;
                    fee = 0;
                    from;
                    encoded;
                };
            };
            case (#burn) {
                {
                    args with kind = #burn;
                    fee = 0;
                    from;
                    encoded;
                };
            };
            case (#transfer) {
                let result : TransactionRequest = {
                    from_subaccount = args.from_subaccount;
                    to = args.to;
                    amount = args.amount;
                    fee = transferFee;
                    memo = args.memo;
                    from = from;
                    encoded = encoded;
                    created_at_time = args.created_at_time;
                    kind = #transfer;
                };
                return result;
            };
        };
    };

    /// Transforms the transaction kind from `variant` to `Text`
    public func kind_to_text(kind : TxKind) : Text {
        switch (kind) {
            case (#mint) "MINT";
            case (#burn) "BURN";
            case (#transfer) "TRANSFER";
        };
    };

    /// Formats the tx request into a finalised transaction
    public func req_to_tx(tx_req : TransactionRequest, index : Nat) : Transaction {

        {
            kind = kind_to_text(tx_req.kind);
            mint = switch (tx_req.kind) {
                case (#mint) { ?tx_req };
                case (_) null;
            };

            burn = switch (tx_req.kind) {
                case (#burn) { ?tx_req };
                case (_) null;
            };

            transfer = switch (tx_req.kind) {
                case (#transfer) { ?tx_req };
                case (_) null;
            };

            index;
            timestamp = Nat64.fromNat(Int.abs(Time.now()));
        };
    };

    public func div_ceil(n : Nat, d : Nat) : Nat {
        (n + d - 1) / d;
    };

    /// Retrieves the balance of an account
    public func get_balance(accounts : AccountBalances, encoded_account : EncodedAccount) : Balance {
        let res = STMap.get(
            accounts,
            Blob.equal,
            Blob.hash,
            encoded_account,
        );

        switch (res) {
            case (?balance) {
                balance;
            };
            case (_) 0;
        };
    };

    /// Updates the balance of an account    
    public func update_balance(
        accounts : AccountBalances,
        encoded_account : EncodedAccount,
        update : (Balance) -> Balance,
    ) {
        let prev_balance = get_balance(accounts, encoded_account);
        let updated_balance = update(prev_balance);

        if (updated_balance != prev_balance) {
            STMap.put(
                accounts,
                Blob.equal,
                Blob.hash,
                encoded_account,
                updated_balance,
            );
        };
    };

    /// Transfers tokens from the sender to the
    /// recipient in the tx request
    public func transfer_balance(
        token : TokenData,
        tx_req : TransactionRequest,
    ) {
        let { encoded; amount } = tx_req;

        update_balance(
            token.accounts,
            encoded.from,
            func(balance) {
                balance - amount;
            },
        );

        update_balance(
            token.accounts,
            encoded.to,
            func(balance) {
                balance + amount;
            },
        );
    };

    /// Function to mint tokens
    public func mint_balance(
        token : TokenData,
        encoded_account : EncodedAccount,
        amount : Balance,
    ) {
        update_balance(
            token.accounts,
            encoded_account,
            func(balance) {
                balance + amount;
            },
        );

        token.minted_tokens += amount;
    };

    /// Function to burn tokens
    public func burn_balance(
        token : TokenData,
        encoded_account : EncodedAccount,
        amount : Balance,
    ) {
        update_balance(
            token.accounts,
            encoded_account,
            func(balance) {
                balance - amount;
            },
        );

        token.burned_tokens += amount;
    };


    public func emptyList(list: List.List<Any>){
        
        while (List.size(list) > 0){
            ignore List.pop(list);
        };
    };

    /// Stable Buffer Module with some additional functions
    public let SB = {
        StableBuffer with slice = func<A>(buffer : StableBuffer.StableBuffer<A>, start : Nat, end : Nat) : [A] {
            let size = SB.size(buffer);
            if (start >= size) {
                return [];
            };

            let slice_len = (Nat.min(end, size) - start) : Nat;

            Array.tabulate(
                slice_len,
                func(i : Nat) : A {
                    SB.get(buffer, i + start);
                },
            );
        };

        toIterFromSlice = func<A>(buffer : StableBuffer.StableBuffer<A>, start : Nat, end : Nat) : Iter.Iter<A> {
            if (start >= SB.size(buffer)) {
                return Itertools.empty();
            };

            Iter.map(
                Itertools.range(start, Nat.min(SB.size(buffer), end)),
                func(i : Nat) : A {
                    SB.get(buffer, i);
                },
            );
        };

        appendArray = func<A>(buffer : StableBuffer.StableBuffer<A>, array : [A]) {
            for (elem in array.vals()) {
                SB.add(buffer, elem);
            };
        };

        getLast = func<A>(buffer : StableBuffer.StableBuffer<A>) : ?A {
            let size = SB.size(buffer);

            if (size > 0) {
                SB.getOpt(buffer, (size - 1) : Nat);
            } else {
                null;
            };
        };

        capacity = func<A>(buffer : StableBuffer.StableBuffer<A>) : Nat {
            buffer.elems.size();
        };

        _clearedElemsToIter = func<A>(buffer : StableBuffer.StableBuffer<A>) : Iter.Iter<A> {
            Iter.map(
                Itertools.range(buffer.count, buffer.elems.size()),
                func(i : Nat) : A {
                    buffer.elems[i];
                },
            );
        };
    };
};
