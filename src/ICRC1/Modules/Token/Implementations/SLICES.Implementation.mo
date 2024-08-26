import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Itertools "mo:itertools/Iter";
import Trie "mo:base/Trie";
import List "mo:base/List";
import Nat8 "mo:base/Nat8";
import Utils "../Utils/Utils";
import T "../../../Types/Types.All";
import Account "../Account/Account";
import MemoryController "../MemoryController/MemoryController";
import { cancelTimer } = "mo:base/Timer";
import Debug "mo:base/Debug";
import StableBuffer "mo:StableBuffer/StableBuffer";
import Model "../../../Types/Types.Model";

/// Slices Token implementations
/// ( == functions needed for the future Slices-apps )
module {

    private type AccountType = T.AccountTypes.Account;
    private type TokenData = T.TokenTypes.TokenData;
    private type Balance = T.Balance;
    private type SetTextParameterResult = T.TokenTypes.SetTextParameterResult;
    private type SetBalanceParameterResult = T.TokenTypes.SetBalanceParameterResult;
    private type SetNat8ParameterResult = T.TokenTypes.SetNat8ParameterResult;
    private type ArchiveInterface = T.ArchiveTypes.ArchiveInterface;
    private type Mint = T.TransactionTypes.Mint;
    private type TransferResult = T.TransactionTypes.TransferResult;
    private type BurnArgs = T.TransactionTypes.BurnArgs;
    private type TxIndex = T.TransactionTypes.TxIndex;
    private type Transaction = T.TransactionTypes.Transaction;
    private type GetTransactionsRequest = T.TransactionTypes.GetTransactionsRequest;
    private type GetTransactionsResponse = T.TransactionTypes.GetTransactionsResponse;
    private type QueryArchiveFn = T.TransactionTypes.QueryArchiveFn;
    private type TransactionRange = T.TransactionTypes.TransactionRange;
    private type ArchivedTransaction = T.TransactionTypes.ArchivedTransaction;
    private type TransferArgs = T.TransactionTypes.TransferArgs;

    public func list_admin_users(token : TokenData) : [Principal] {
        Account.list_admin_users(token : TokenData);
    };

    public func get_allowance_list(memoryController: MemoryController.MemoryController, owner : T.AccountTypes.Account):[T.TransactionTypes.AllowanceInfo] {

        memoryController.databaseController.get_allowance_list(owner);                 
    };

    // Will return 0 if 'principalFrom' od 'principalTo' is whitelisted, else default Fee will be returned
    public func get_real_token_fee(principalFrom : Principal, principalTo : Principal, token : TokenData) : Balance {
        Utils.get_real_token_fee(principalFrom, principalTo, token);
    };

    /// Returns the list of the token-holders - with their balances included
    public func get_holders(token : TokenData, index : ?Nat, count : ?Nat) : [T.AccountTypes.AccountBalanceInfo] {

        let size : Nat = token.accounts._size;
        let indexValue : Nat = switch (index) {
            case (?index) index;
            case (null) 0;
        };

        let countValue : Nat = switch (count) {
            case (?count) count;
            case (null) size;
        };

        if (indexValue >= size) {
            return [];
        };
        let maxNumbersOfHoldersToReturn : Nat = 5000;

        var countToUse : Nat = Nat.min(Nat.min(countValue, size -indexValue), maxNumbersOfHoldersToReturn);

        let defaultAccount : T.AccountTypes.Account = {
            owner = Principal.fromText("aaaaa-aa");
            subaccount = null;
        };
        var iter = Trie.iter(token.accounts.trie);

        //Because of reverse order:
        let revIndex : Nat = size - (indexValue + countToUse);

        iter := Itertools.skip(iter, revIndex);
        iter := Itertools.take(iter, countToUse);

        var resultList : List.List<T.AccountTypes.AccountBalanceInfo> = List.nil<T.AccountTypes.AccountBalanceInfo>();
        var resultIter = Iter.fromList<T.AccountTypes.AccountBalanceInfo>(resultList);

        for ((k : Blob, v : T.CommonTypes.Balance) in iter) {

            let account : ?T.AccountTypes.Account = Account.decode(k);
            let balance : Nat = v;
            let newItem : T.AccountTypes.AccountBalanceInfo = {
                account = Option.get(account, defaultAccount);
                balance = balance;
            };
            resultIter := Itertools.prepend<T.AccountTypes.AccountBalanceInfo>(newItem, resultIter);
        };

        return Iter.toArray<T.AccountTypes.AccountBalanceInfo>(resultIter);
    };

    /// Returns the number of individual token holders
    public func get_holders_count(token : TokenData) : Nat {
        token.accounts._size;
    };

    /// Get the canister's cycle balance information for all the created archive canisters.
    /// If this method was called from minting-owner account then also the canister-id's are included.
    public func all_canister_stats(
        hidePrincipal : Bool,
        mainTokenPrincipal : Principal,
        mainTokenBalance : Balance,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
    ) : async* [T.CanisterTypes.CanisterStatsResponse] {

        var showFullInfo = false;
        if (hidePrincipal == false) {
            showFullInfo := true;
        };

        var returnList : List.List<T.CanisterTypes.CanisterStatsResponse> = List.nil<T.CanisterTypes.CanisterStatsResponse>();

        let itemForMainToken : T.CanisterTypes.CanisterStatsResponse = {
            name = "Main token";
            principal = Principal.toText(mainTokenPrincipal);
            cycles_balance = mainTokenBalance;
        };
        returnList := List.push(itemForMainToken, returnList);

        let iter = List.toIter<Principal>(archive_canisterIds.canisterIds);
        var counter = 1;
        for (item : Principal in iter) {
            let principalText : Text = Principal.toText(item);
            let archive : T.ArchiveTypes.ArchiveInterface = actor (principalText);
            let archiveCyclesBalance = await archive.cycles_available();

            let newItem : T.CanisterTypes.CanisterStatsResponse = {
                name = "Archive canister No:" #debug_show (counter);
                principal = switch (showFullInfo) {
                    case (true) Principal.toText(item);
                    case (false) "<Hidden>";
                };
                cycles_balance = archiveCyclesBalance;
            };
            returnList := List.push(newItem, returnList);
            counter := counter + 1;
        };
        returnList := List.reverse(returnList);

        return List.toArray<T.CanisterTypes.CanisterStatsResponse>(returnList);
    };

    public func feewhitelisting_get_list(token : TokenData) : [Principal] {
        return List.toArray<Principal>(token.feeWhitelistedPrincipals);
    };

    /// Returns array of the transactions stored on the main-token (not went into archive yet)
    /// This method is only used for the backup/restoring function
    public func get_internal_transactions(token : TokenData, index : ?Nat, count : ?Nat) : [Transaction] {

        let size : Nat = StableBuffer.size(token.transactions);

        let indexValue : Nat = switch (index) {
            case (?index) index;
            case (null) 0;
        };

        let countValue : Nat = switch (count) {
            case (?count) count;
            case (null) size;
        };

        if (indexValue >= size) {
            return [];
        };
        let maxNumbersToReturn : Nat = 5000;
        var countToUse : Nat = Nat.min(Nat.min(countValue, size -indexValue), maxNumbersToReturn);

        var iter = StableBuffer.vals<Transaction>(token.transactions);

        //Because of reverse order:
        let revIndex : Nat = size - (indexValue + countToUse);

        iter := Itertools.skip(iter, revIndex);
        iter := Itertools.take(iter, countToUse);

        var resultList : List.List<Transaction> = List.nil<Transaction>();
        var resultIter = Iter.fromList<Transaction>(resultList);

        for (transActionItem in iter) {
            resultIter := Itertools.prepend<Transaction>(transActionItem, resultIter);
        };

        return Iter.toArray<Transaction>(resultIter);
    };

    // --------------------------------------------------------------------------------
    // Set or Update values

    public func admin_add_admin_user(caller : Principal, principalToAddAsAdmin : Principal, token : TokenData) : Result.Result<Text, Text> {
        Account.admin_add_admin_user(caller : Principal, principalToAddAsAdmin : Principal, token : TokenData);
    };
    public func admin_remove_admin_user(caller : Principal, principalToRemoveAsAdmin : Principal, token : TokenData) : Result.Result<Text, Text> {
        Account.admin_remove_admin_user(caller : Principal, principalToRemoveAsAdmin : Principal, token : TokenData);
    };

    public func feewhitelisting_add_principal(caller : Principal, principal : Principal, token : TokenData) : Result.Result<Text, Text> {
        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == false) {
            return #err("Only owner or admin users can exexcute this function.");
        };

        if (
            List.size<Principal>(token.feeWhitelistedPrincipals) > 0 and
            List.some<Principal>(token.feeWhitelistedPrincipals, func(n) { n == principal })
        ) {
            return #err("This principal is already fee white listed.");
        };
        token.feeWhitelistedPrincipals := List.push<Principal>(principal, token.feeWhitelistedPrincipals);
        return #ok("The principal was added in the fee white list.");
    };

    public func feewhitelisting_remove_principal(caller : Principal, principal : Principal, token : TokenData) : Result.Result<Text, Text> {
        let userIsAdminOrOwner = Account.user_is_owner_or_admin(caller, token);
        if (userIsAdminOrOwner == false) {
            return #err("Only owner or admin users can exexcute this function.");
        };

        if (
            List.size<Principal>(token.feeWhitelistedPrincipals) > 0 and
            List.some<Principal>(token.feeWhitelistedPrincipals, func(n) { n == principal })
        ) {
            token.feeWhitelistedPrincipals := List.filter<Principal>(token.feeWhitelistedPrincipals, func n { n != principal });
            return #ok("Ok. The principal was removed from the fee white list.");
        };
        token.feeWhitelistedPrincipals := List.push<Principal>(principal, token.feeWhitelistedPrincipals);
        return #ok("The principal is not fee white listed. Nothing to remove.");
    };

    public func up_or_down_scale_token_internal(
        numberOfDecimalPlaces : Nat8,
        isUpscaling : Bool,
        token : TokenData,
        memoryController : MemoryController.MemoryController,
    ) : async () {

        // First cancel the timer
        if (isUpscaling == true) {
            cancelTimer(memoryController.model.settings.tokens_upscaling_timer_id);
        } else {
            cancelTimer(memoryController.model.settings.tokens_downscaling_timer_id);
        };
        memoryController.model.settings.token_operations_are_paused := false;

        await up_or_down_scale_token_directly_internal(numberOfDecimalPlaces, isUpscaling, token);

        // Set upscale mode to normal again
        if (isUpscaling == true) {
            memoryController.model.settings.tokens_upscaling_mode := #idle;
        } else {
            memoryController.model.settings.tokens_downscaling_mode := #idle;
        };

    };

    // We will need this function for the tests, therefore this function was extracted
    public func up_or_down_scale_token_directly_internal(
        numberOfDecimalPlaces : Nat8,
        isUpscaling : Bool,
        token : TokenData,
    ) : async () {

        // Now do the upscaling
        let factor : Nat = Nat.pow(10, Nat8.toNat(numberOfDecimalPlaces));

        if (isUpscaling == true) {
            token.max_supply *= factor;
            token.minted_tokens *= factor;
            token.burned_tokens *= factor;

        } else {
            token.max_supply /= factor;
            token.minted_tokens /= factor;
            token.burned_tokens /= factor;
        };

        var iter = Trie.iter(token.accounts.trie);
        var encodedAccounts : List.List<Blob> = List.nil<Blob>();
        for ((encodedAccount : Blob, balance : T.CommonTypes.Balance) in iter) {
            encodedAccounts := List.push<Blob>(encodedAccount, encodedAccounts);
        };

        for (encodedAccount : Blob in List.toIter<Blob>(encodedAccounts)) {
            //Update the balance in accounts

            if (isUpscaling == true) {
                Utils.update_balance(
                    token.accounts,
                    encodedAccount,
                    func(balance) {
                        balance * factor;
                    },
                );

            } else {
                Utils.update_balance(
                    token.accounts,
                    encodedAccount,
                    func(balance) {
                        balance / factor;
                    },
                );

            };

        };
    };

    // --------------------------------------------------------------------------------

};
