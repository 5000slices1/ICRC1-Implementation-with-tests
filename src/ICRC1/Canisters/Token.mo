import List "mo:base/List";
import { setTimer; recurringTimer; cancelTimer } = "mo:base/Timer";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import ICRC1 "../Modules/Token/ICRC1Token";
import ICRC2 "../Modules/Token/ICRC2Token";
import ExtendedToken "../Modules/Token/ExtendedToken";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
//import Error "mo:base/Error";
//import Itertools "mo:itertools/Iter";
//import Trie "mo:base/Trie";
//import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import T "../Types/Types.All";
import Constants "../Types/Types.Constants";
import Account "../Modules/Token/Account/Account";
//import Region "mo:base/Region";
//import Option "mo:base/Option";
import Utils "../Modules/Token/Utils/Utils";
import Initializer "../Modules/Token/Initializer/Initializer";
import Model "../Types/Types.Model";
import Converters = "../Modules/Converters/Converters";
import MemoryController "../Modules/Token/MemoryController/MemoryController";
import ArchiveHelper "../Modules/Token/Archive/ArchiveHelper";


/// The actor class for the main token
shared ({ caller = _owner }) actor class Token(init_args : ?T.TokenTypes.TokenInitArgs) : async T.TokenTypes.FullInterface = this {

    //The value of this variable should only be changed by the function 'ConvertArgs'
    //private stable var wasInitializedWithArguments : Bool = false;
    // private stable var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds = {
    //     var canisterIds = List.nil<Principal>();
    // };
    // private stable var tokenCanisterId : Principal = Principal.fromText("aaaaa-aa");

    // private stable var autoTopupData : T.CanisterTypes.CanisterAutoTopUpData = {
    //     var autoCyclesTopUpEnabled = false;
    //     var autoCyclesTopUpMinutes : Nat = 60 * 12; //12 hours
    //     var autoCyclesTopUpTimerId : Nat = 0;
    //     var autoCyclesTopUpOccuredNumberOfTimes : Nat = 0;
    // };


    /*
    private func ConvertArgs(init_arguments : ?T.TokenTypes.TokenInitArgs) : ?T.TokenTypes.InitArgs {
        if (init_arguments == null) {

            if (wasInitializedWithArguments == false) {
                let infoText : Text = "ERROR! Empty argument in dfx deploy is only allowed for canister updates";
                Debug.print(infoText);
                Debug.trap(infoText);
            };
            return null;
        };

        if (wasInitializedWithArguments == true) {
            let infoText : Text = "ERROR! Re-initializing is not allowed";
            Debug.print(infoText);
            Debug.trap(infoText);
        } else {

            var argsToUse : T.TokenTypes.TokenInitArgs = switch (init_arguments) {
                case null return null; // should never happen
                case (?tokenArgs) tokenArgs;
            };

            let icrc1_args : T.TokenTypes.InitArgs = {
                argsToUse with minting_account = Option.get(argsToUse.minting_account, { owner = _owner; subaccount = null });
            };

            if (icrc1_args.initial_balances.size() < 1) {
                if (icrc1_args.minting_allowed == false) {
                    let infoText : Text = "ERROR! When minting feature is disabled at least one initial balances account is needed.";
                    Debug.print(infoText);
                    Debug.trap(infoText);
                };
            } else {

                for ((i, (account, balance)) in Itertools.enumerate(icrc1_args.initial_balances.vals())) {

                    if (account.owner == icrc1_args.minting_account.owner) {
                        let infoText : Text = "ERROR! Minting account was specified in initial balances account. This is not allowed.";
                        Debug.print(infoText);
                        Debug.trap(infoText);

                    };
                };
            };

            //Now check the balance of cycles available:
            let amount = Cycles.balance();
            if (amount < Constants.TOKEN_INITIAL_CYCLES_REQUIRED) {
                let missingBalance : Nat = Constants.TOKEN_INITIAL_CYCLES_REQUIRED - amount;
                let infoText : Text = "\r\nERROR! At least " #debug_show (Constants.TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED)
                # " cycles are needed for deployment. \r\n "
                # "- Available cycles: " #debug_show (amount) # "\r\n"
                # "- Missing cycles: " #debug_show (missingBalance) # "\r\n"
                # " -> You can use the '--with-cycles' command in dfx deploy. \r\n"
                # "    For example: \r\n"
                # "    'dfx deploy icrc1 --with-cycles 3000000000000'";
                Debug.print(infoText);
                Debug.trap(infoText);
            };

            wasInitializedWithArguments := true;
            return Option.make(icrc1_args);
        };
    };
    */

    private stable var model:Model.Model = Initializer.init_model();

    //Convert argument, because 'init_args' can now be null, in case of upgrade scenarios. ('dfx deploy')
    let init_arguments : ?T.TokenTypes.InitArgs = Converters.ConvertTokenInitArgs(init_args, model,_owner);

    private stable let token : T.TokenTypes.TokenData = switch (init_arguments) {
        case null {
            Debug.trap("Initialize token with no arguments not allowed.");
        };
        case (?initArgsNotNull) Initializer.tokenInit(initArgsNotNull);
    };

    private let memoryController:MemoryController.MemoryController = MemoryController.MemoryController(model);
        

    // ------------------------------------------------------------------------------------------
    // ICRC1

    public shared query func icrc1_name() : async Text {
        ICRC1.icrc1_name(token);
    };

    public shared query func icrc1_symbol() : async Text {
        ICRC1.icrc1_symbol(token);
    };

    public shared query func icrc1_decimals() : async Nat8 {
        ICRC1.icrc1_decimals(token);
    };

    public shared query func icrc1_fee() : async T.Balance {
        ICRC1.icrc1_fee(token);
    };

    //Fee is zero for Fee-whitelisted principals
    public shared query func fee(from : Principal, to : Principal) : async T.Balance {

        Utils.get_token_fee(from, to, token);
    };

    public shared query func icrc1_metadata() : async [T.TokenTypes.MetaDatum] {
        ICRC1.icrc1_metadata(token);
    };

    public shared query func icrc1_total_supply() : async T.Balance {
        ICRC1.icrc1_total_supply(token);
    };

    public shared query func icrc1_minting_account() : async ?T.AccountTypes.Account {
        ?ICRC1.icrc1_minting_account(token);
    };

    public shared query func icrc1_balance_of(args : T.AccountTypes.Account) : async T.Balance {
        ICRC1.icrc1_balance_of(token, args);
    };

    public shared query func icrc1_supported_standards() : async [T.TokenTypes.SupportedStandard] {
        ICRC1.icrc1_supported_standards(token);
    };

    public shared ({ caller }) func icrc1_transfer(args : T.TransactionTypes.TransferArgs) : async T.TransactionTypes.TransferResult {

        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ICRC1.icrc1_transfer(token, args, caller, model.settings.archive_canisterIds);
    };

    // ------------------------------------------------------------------------------------------


    // ------------------------------------------------------------------------------------------
    // ICRC2
   
    public shared ({ caller }) func icrc2_approve(approveArgs : T.TransactionTypes.ApproveArgs) : async T.TransactionTypes.ApproveResult {
        ICRC2.icrc2_approve(caller, approveArgs, token, memoryController);        
    };

    public shared query func icrc2_allowance(allowanceArgs : T.TransactionTypes.AllowanceArgs) : async T.TransactionTypes.Allowance {        
        ICRC2.icrc2_allowance(allowanceArgs, memoryController);
    };

    public shared ({ caller }) func icrc2_transfer_from(transferFromArgs : T.TransactionTypes.TransferFromArgs) : async T.TransactionTypes.TransferFromResponse {
        await* ICRC2.icrc2_transfer_from(caller, transferFromArgs, token, memoryController);        
    };

    // ------------------------------------------------------------------------------------------


    // ------------------------------------------------------------------------------------------
    // Extended token functions

public shared ({ caller }) func mint(args : T.TransactionTypes.Mint) : async T.TransactionTypes.TransferResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.mint(token, args, caller, model.settings.archive_canisterIds);
    };

    public shared ({ caller }) func burn(args : T.TransactionTypes.BurnArgs) : async T.TransactionTypes.TransferResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.burn(token, args, caller, model.settings.archive_canisterIds);
    };

    public shared ({ caller }) func set_name(name : Text) : async T.TokenTypes.SetTextParameterResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.set_name(token, name, caller);
    };

    public shared ({ caller }) func set_symbol(symbol : Text) : async T.TokenTypes.SetTextParameterResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.set_symbol(token, symbol, caller);
    };

    public shared ({ caller }) func set_logo(logo : Text) : async T.TokenTypes.SetTextParameterResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.set_logo(token, logo, caller);
    };

    public shared ({ caller }) func set_fee(fee : T.Balance) : async T.TokenTypes.SetBalanceParameterResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.set_fee(token, fee, caller);
    };

    public shared ({ caller }) func set_decimals(decimals : Nat8) : async T.TokenTypes.SetNat8ParameterResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.set_decimals(token, decimals, caller);
    };

    public shared ({ caller }) func set_min_burn_amount(min_burn_amount : T.Balance) : async T.TokenTypes.SetBalanceParameterResult {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.set_min_burn_amount(token, min_burn_amount, caller);
    };

    public shared query func min_burn_amount() : async T.Balance {
        ExtendedToken.min_burn_amount(token);
    };

    public shared query func get_archive() : async T.ArchiveTypes.ArchiveInterface {
        ExtendedToken.get_archive(token);
    };

    public shared query func get_total_tx() : async Nat {
        ExtendedToken.total_transactions(token);
    };

    public shared query func get_archive_stored_txs() : async Nat {
        ExtendedToken.get_archive_stored_txs(token);
    };

    // Functions for integration with the rosetta standard
    public shared query func get_transactions(req : T.TransactionTypes.GetTransactionsRequest) : async T.TransactionTypes.GetTransactionsResponse {
        ExtendedToken.get_transactions(token, req);
    };

    // Additional functions not included in the ICRC1 standard
    public shared func get_transaction(i : T.TransactionTypes.TxIndex) : async ?T.TransactionTypes.Transaction {
        await* ExtendedToken.get_transaction(token, i);
    };

    //Only the owner can call this method
    public shared ({ caller }) func admin_add_admin_user(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };

        return ExtendedToken.admin_add_admin_user(caller, principal, token);
    };

    //Only the owner can call this method
    public shared ({ caller }) func admin_remove_admin_user(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };

        return ExtendedToken.admin_remove_admin_user(caller, principal, token);
    };

    public shared query func list_admin_users() : async [Principal] {
        return ExtendedToken.list_admin_users(token);
    };

    public shared ({ caller }) func feewhitelisting_add_principal(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };
        return ExtendedToken.feewhitelisting_add_principal(caller, principal, token);
    };

    public shared ({ caller }) func feewhitelisting_remove_principal(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };
        return ExtendedToken.feewhitelisting_remove_principal(caller, principal, token);
    };

    public shared query func feewhitelisting_get_list() : async [Principal] {
        return ExtendedToken.feewhitelisting_get_list(token);
    };



    /// Retrieve information for the main token and all dynamically added archive canisters:
    /// - The balance for each canister is shown
    /// - The canister-id for each canister is shown when this function is called by the minting-owner or admin
    public shared ({ caller }) func all_canister_stats() : async [T.CanisterTypes.CanisterStatsResponse] {
        if (model.settings.tokenCanisterId == Principal.fromText("aaaaa-aa")) {
            model.settings.tokenCanisterId := Principal.fromActor(this);
        };
        let balance = Cycles.balance();
        var hidePrincipals : Bool = true;
        if (Account.user_is_owner_or_admin(caller, token) == true){
            hidePrincipals:=false;
        };

        await* ExtendedToken.all_canister_stats(hidePrincipals, model.settings.tokenCanisterId, balance, model.settings.archive_canisterIds);
    };

    /// Show the token holders
    public shared query func get_holders_count() : async Nat {
        token.accounts._size;
    };

    /// Get list of the holders
    /// The returned list can contain maximum 5000 entries. Therefore the additional 'index' and 'count' parameter in case
    /// there are more than 5000 entries available.
    public shared query func get_holders(index : ?Nat, count : ?Nat) : async [T.AccountTypes.AccountBalanceInfo] {
        ExtendedToken.get_holders(token, index, count);
    };



   ///This function enables the timer to auto fill the dynamically created archive canisters
    public shared ({ caller }) func auto_topup_cycles_enable(minutes : ?Nat) : async Result.Result<Text, Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false){
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };
       

        let minutesToUse : Nat = switch (minutes) {
            case (?minutes) minutes;
            case (null) 60 * 12; //12 hours
        };

        if (minutesToUse < 15) {
            return #err("Error. At least 15 minutes timer is required.");
        };

        if (model.settings.autoTopupData.autoCyclesTopUpEnabled == false or minutesToUse != model.settings.autoTopupData.autoCyclesTopUpMinutes) {
            model.settings.autoTopupData.autoCyclesTopUpMinutes := minutesToUse;
            auto_topup_cycles_enable_internal<system>();
            #ok("Automatic cycles topUp for archive canisters is now enabled. Check every " # debug_show (model.settings.autoTopupData.autoCyclesTopUpMinutes) # " minutes.");
        } else {
            #ok("Automatic cycles topUp for archive canisters was already enabled. Check every " # debug_show (model.settings.autoTopupData.autoCyclesTopUpMinutes) # " minutes.");
        };

    };

    /// This functions disables the auto fill up timer
    public shared ({ caller }) func auto_topup_cycles_disable() : async Result.Result<Text, Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false){
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        cancelTimer(model.settings.autoTopupData.autoCyclesTopUpTimerId);
        model.settings.autoTopupData.autoCyclesTopUpEnabled := false;
        #ok("Automatic cycles topUp for archive canisters is now disabled");
    };

    /// Show the status of the auto fill up timer settings
    public shared func auto_topup_cycles_status() : async T.CanisterTypes.CanisterAutoTopUpDataResponse {

        let response : T.CanisterTypes.CanisterAutoTopUpDataResponse = {
            autoCyclesTopUpEnabled = model.settings.autoTopupData.autoCyclesTopUpEnabled;
            autoCyclesTopUpMinutes = model.settings.autoTopupData.autoCyclesTopUpMinutes;
            autoCyclesTopUpTimerId = model.settings.autoTopupData.autoCyclesTopUpTimerId;
            autoCyclesTopUpOccuredNumberOfTimes = model.settings.autoTopupData.autoCyclesTopUpOccuredNumberOfTimes;
        };

        response;
    };


       // Deposit cycles into this canister.
    public shared func deposit_cycles<system>() : async () {
        let amount = Cycles.available();
        let accepted = Cycles.accept<system>(amount);
        assert (accepted == amount);
    };

    public shared query func cycles_balance() : async Nat {
        Cycles.balance();
    };



    // ------------------------------------------------------------------------------------------


    // ------------------------------------------------------------------------------------------
    // Helper functions

    private func cyclesAvailable() : Nat {
        Cycles.balance();
    };

    private func auto_topup_cycles_enable_internal<system>() {
        cancelTimer(model.settings.autoTopupData.autoCyclesTopUpTimerId);

        let timerSeconds : Nat = model.settings.autoTopupData.autoCyclesTopUpMinutes * 60;
        model.settings.autoTopupData.autoCyclesTopUpTimerId := recurringTimer<system>(
            #seconds timerSeconds,
            func() : async () {
                await auto_topup_cycles_timer_tick<system>();
            },
        );

        model.settings.autoTopupData.autoCyclesTopUpEnabled := true;
    };

    private func auto_topup_cycles_timer_tick<system>() : async () {

        let totalDynamicCanisters = List.size(model.settings.archive_canisterIds.canisterIds);
        if (totalDynamicCanisters <= 0) {
            return;
        };

        var balance = Cycles.balance();
        if (balance < T.ConstantTypes.TOKEN_CYCLES_TO_KEEP + (T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL)) {
            return;
        };

        let iter = List.toIter<Principal>(model.settings.archive_canisterIds.canisterIds);

        for (item : Principal in iter) {
            let principalText : Text = Principal.toText(item);
            let archive : T.ArchiveTypes.ArchiveInterface = actor (principalText);
            let archiveCyclesBalance = await archive.cycles_available();
            if (archiveCyclesBalance < T.ConstantTypes.ARCHIVE_CYCLES_REQUIRED) {
                if (balance > T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL + T.ConstantTypes.TOKEN_CYCLES_TO_KEEP) {
                    Cycles.add<system>(T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL);
                    await archive.deposit_cycles();
                    balance := Cycles.balance();
                    model.settings.autoTopupData.autoCyclesTopUpOccuredNumberOfTimes := model.settings.autoTopupData.autoCyclesTopUpOccuredNumberOfTimes + 1;
                };
            };

        };

    };

    // ------------------------------------------------------------------------------------------


    if (model.settings.autoTopupData.autoCyclesTopUpEnabled == true) {
        ignore do ? {
            auto_topup_cycles_enable_internal<system>();
        };
    };



};
