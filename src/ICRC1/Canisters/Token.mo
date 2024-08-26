import List "mo:base/List";
import { setTimer; recurringTimer; cancelTimer } = "mo:base/Timer";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import ICRC1 "../Modules/Token/Implementations/ICRC1.Implementation";
import ICRC2 "../Modules/Token/Implementations/ICRC2.Implementation";
import SlicesToken "../Modules/Token/Implementations/SLICES.Implementation";
import ExtendedToken "../Modules/Token/Implementations/EXTENDED.Implementation";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Float "mo:base/Float";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import T "../Types/Types.All";
import Constants "../Types/Types.Constants";
import Account "../Modules/Token/Account/Account";
import Initializer "../Modules/Token/Initializer/Initializer";
import Model "../Types/Types.Model";
import Converters = "../Modules/Converters/Converters";
import MemoryController "../Modules/Token/MemoryController/MemoryController";
import Utils "../Modules/Token/Utils/Utils";
import TypesBackupRestore "../Types/Types.BackupRestore";
import CommonTypes "../Types/Types.Common";


/// The actor class for the main token
shared ({ caller = _owner }) actor class Token(init_args : ?T.TokenTypes.TokenInitArgs) : async T.TokenTypes.FullInterface = this {
    
    private stable var model : Model.Model = Initializer.init_model();

    //Convert argument, because 'init_args' can now be null, in case of upgrade scenarios. ('dfx deploy')
    let init_arguments : ?T.TokenTypes.InitArgs = Converters.ConvertTokenInitArgs(init_args, model, _owner);

    private stable var token : T.TokenTypes.TokenData = switch (init_arguments) {
        case null {
            Debug.trap("Initialize token with no arguments not allowed.");
        };
        case (?initArgsNotNull) Initializer.tokenInit(initArgsNotNull);
    };

    private let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

    // ONLY for debugging purposes:
    // public shared query func get_token_maindata() : async TypesBackupRestore.BackupCommonTokenData {
    //     Converters.ConvertToTokenMainData(token);
    // };
     
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

    public shared query func icrc1_supported_standards() : async [CommonTypes.SupportedStandard] {        
        ICRC1.icrc1_supported_standards(token);
    };

    public shared ({ caller }) func icrc1_transfer(args : T.TransactionTypes.TransferArgs) : async T.TransactionTypes.TransferResult {                
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        
        await* ICRC1.icrc1_transfer(token, args, caller, model.settings.archive_canisterIds, model);
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

    // -------------------------------------------------------------------------------------------
    // SLICES token functions


    public shared query func get_allowance_list(owner : T.AccountTypes.Account):async [T.TransactionTypes.AllowanceInfo] {
        SlicesToken.get_allowance_list(memoryController,owner);
    };
    //Fee is zero for Fee-whitelisted principals, else defaultFee is returned
    public shared query func real_fee(from : Principal, to : Principal) : async T.Balance {        
        SlicesToken.get_real_token_fee(from, to, token);
    };

    //Only the owner can call this method
    public shared ({ caller }) func admin_add_admin_user(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };

        return SlicesToken.admin_add_admin_user(caller, principal, token);
    };

    //Only the owner can call this method
    public shared ({ caller }) func admin_remove_admin_user(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };

        return SlicesToken.admin_remove_admin_user(caller, principal, token);
    };

    public shared query func list_admin_users() : async [Principal] {
        return SlicesToken.list_admin_users(token);
    };

    public shared ({ caller }) func feewhitelisting_add_principal(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };
        return SlicesToken.feewhitelisting_add_principal(caller, principal, token);
    };

    public shared ({ caller }) func feewhitelisting_remove_principal(principal : Principal) : async Result.Result<Text, Text> {
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #err("Not enough free Cycles available");
        };
        
        return SlicesToken.feewhitelisting_remove_principal(caller, principal, token);
    };

    public shared query func feewhitelisting_get_list() : async [Principal] {
        return SlicesToken.feewhitelisting_get_list(token);
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
        if (Account.user_is_owner_or_admin(caller, token) == true) {
            hidePrincipals := false;
        };

        await* SlicesToken.all_canister_stats(hidePrincipals, model.settings.tokenCanisterId, balance, model.settings.archive_canisterIds);
    };

    /// Get token holders count
    public shared query func get_holders_count() : async Nat {
        SlicesToken.get_holders_count(token);
    };

    /// Get list of the holders
    /// The returned list can contain maximum 5000 entries. Therefore the additional 'index' and 'count' parameter in case
    /// there are more than 5000 entries available.
    public shared query func get_holders(index : ?Nat, count : ?Nat) : async [T.AccountTypes.AccountBalanceInfo] {
        SlicesToken.get_holders(token, index, count);
    };

    public shared ({ caller }) func tokens_amount_upscale<system>(numberOfDecimalPlaces : Nat8) : async Result.Result<Text, Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        if (numberOfDecimalPlaces < 1) {
            return #err("The minimum number for scaling is 1");
        };

        let current_total_supply : Nat = ICRC1.icrc1_total_supply(token);
        let current_max_supply : Nat = token.max_supply;

        let factor : Nat = Nat.pow(10, Nat8.toNat(numberOfDecimalPlaces));
        let floatDecimals : Float = Float.fromInt(Nat8.toNat(token.decimals));

        let new_total_supply = current_total_supply * factor;
        let new_max_supply = current_max_supply * factor;

        var request_Should_be_used = true;
        switch (model.settings.tokens_upscaling_mode) {
            case (#requested(prevPrincipal, time, scale_places)) {
                if (prevPrincipal == caller and scale_places == numberOfDecimalPlaces) {
                    // check if within time frame
                    let timeNow : Int = Time.now();
                    let timeWindowInSeconds = 5 * 60 * 1000_000_000; // 5 minutes as nano seconds
                    let expirationTime : Int = timeNow + timeWindowInSeconds;
                    if (timeNow <= expirationTime) {
                        request_Should_be_used := false;
                    };
                };
            };
            case (#progressing(decimalPlaces)) {
                return #err("Upscaling is still on progress...");
            };
            case (_) {

            };
        };

        if (request_Should_be_used == true) {

            model.settings.tokens_upscaling_mode := #requested(caller, Time.now(), numberOfDecimalPlaces);

            let returnText : Text = "Warning, you want to upscale the token amount.\n" #
            "- Current status:\n" #
            "  Max supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(current_max_supply) / (10 ** floatDecimals)))) # " tokens.\n" #
            "  Total circ. supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(current_total_supply) / (10 ** floatDecimals)))) # " tokens.\n\n" #

            "- After upscaling:\n" #
            "  Max supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(new_max_supply) / (10 ** floatDecimals)))) # " tokens.\n" #
            "  Total circ. supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(new_total_supply) / (10 ** floatDecimals)))) # " tokens.\n\n" #

            "If this is correct and you still want to upscale the token amount, then please call this function again with the next 5 minutes.";

            return #ok(returnText);
        };

        // First set the token operations into pause-mode (with maximum wait-time set to 24 hours)
        let dayAsMinutes : Nat = 60 * 24;
        token_operations_set_to_pause_internal<system>(dayAsMinutes);

        model.settings.tokens_upscaling_mode := #progressing(numberOfDecimalPlaces);

        // we will first wait 2 minutes, to make sure that no other message processing is taking place.
        let waitSecondsBeforeStartingTheScaling : Nat = 2 * 60;

        model.settings.tokens_upscaling_timer_id := setTimer<system>(
            #seconds waitSecondsBeforeStartingTheScaling,
            func<system>() : async () {
                await SlicesToken.up_or_down_scale_token_internal(numberOfDecimalPlaces, true, token, memoryController);
            },
        );

        return #ok("Ok. Upscaling token is on progress...");
    };

    public shared ({ caller }) func tokens_amount_downscale<system>(numberOfDecimalPlaces : Nat8) : async Result.Result<Text, Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        if (numberOfDecimalPlaces < 1) {
            return #err("The minimum number for scaling is 1");
        };

        let current_total_supply : Nat = ICRC1.icrc1_total_supply(token);
        let current_max_supply : Nat = token.max_supply;

        let factor : Nat = Nat.pow(10, Nat8.toNat(numberOfDecimalPlaces));
        let floatDecimals : Float = Float.fromInt(Nat8.toNat(token.decimals));

        let new_total_supply = current_total_supply / factor;
        let new_max_supply = current_max_supply / factor;

        var request_Should_be_used = true;
        switch (model.settings.tokens_downscaling_mode) {
            case (#requested(prevPrincipal, time, scale_places)) {
                if (prevPrincipal == caller and scale_places == numberOfDecimalPlaces) {
                    // check if within time frame
                    let timeNow : Int = Time.now();
                    let timeWindowInSeconds = 5 * 60 * 1000_000_000; // 5 minutes as nano seconds
                    let expirationTime : Int = timeNow + timeWindowInSeconds;
                    if (timeNow <= expirationTime) {
                        request_Should_be_used := false;
                    };
                };
            };
            case (#progressing(decimalPlaces)) {
                return #err("Upscaling is still on progress...");
            };
            case (_) {

            };
        };

        if (request_Should_be_used == true) {

            model.settings.tokens_downscaling_mode := #requested(caller, Time.now(), numberOfDecimalPlaces);

            let returnText : Text = "Warning, you want to downscale the token amount.\n" #
            "- Current status:\n" #
            "  Max supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(current_max_supply) / (10 ** floatDecimals)))) # " tokens.\n" #
            "  Total circ. supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(current_total_supply) / (10 ** floatDecimals)))) # " tokens.\n\n" #

            "- After upscaling:\n" #
            "  Max supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(new_max_supply) / (10 ** floatDecimals)))) # " tokens.\n" #
            "  Total circ. supply: " #debug_show (Int.abs(Float.toInt(Float.fromInt(new_total_supply) / (10 ** floatDecimals)))) # " tokens.\n\n" #

            "If this is correct and you still want to downscale the token amount, then please call this function again with the next 5 minutes.";

            return #ok(returnText);
        };

        // First set the token operations into pause-mode (with maximum wait-time set to 24 hours)
        let dayAsMinutes : Nat = 60 * 24;
        token_operations_set_to_pause_internal<system>(dayAsMinutes);

        model.settings.tokens_downscaling_mode := #progressing(numberOfDecimalPlaces);

        // we will first wait 2 minutes, to make sure that no other message processing is taking place.
        let waitSecondsBeforeStartingTheScaling : Nat = 2 * 60;

        model.settings.tokens_downscaling_timer_id := setTimer<system>(
            #seconds waitSecondsBeforeStartingTheScaling,
            func<system>() : async () {
                await SlicesToken.up_or_down_scale_token_internal(numberOfDecimalPlaces, false, token, memoryController);
            },
        );

        return #ok("Ok. Downscaling token is on progress...");
    };
    // -------------------------------------------------------------------------------------------

    // ------------------------------------------------------------------------------------------
    // Additional token functions

    public shared ({ caller }) func backup(backupParameter : TypesBackupRestore.BackupParameter) : async Result.Result<(isComplete : Bool, data : [Nat8]), Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        ExtendedToken.backup(memoryController, token, backupParameter);
    };

    public shared ({ caller }) func restore(restoreInfo : TypesBackupRestore.RestoreInfo) : async Result.Result<Text, Text> {

        if (caller != token.minting_account.owner){        
            return #err("Unauthorized: Only minting account can call this function..");
        };

        ExtendedToken.restore(memoryController, token, restoreInfo);
    };

    /// Pause token operations. This is useful if we do some time consuming operations like update/upgrade or token scaling...
    public shared ({ caller }) func token_operation_pause<system>(minutes : Nat) : async Result.Result<Text, Text> {
        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        token_operations_set_to_pause_internal<system>(minutes);
        return #ok("Token operations are paused.");
    };

    // The token operations will resume again....
    public shared ({ caller }) func token_operation_continue() : async Result.Result<Text, Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        if (model.settings.token_operations_timer_id > 0 or model.settings.token_operations_are_paused == true) {
            cancelTimer(model.settings.token_operations_timer_id);
        };
        model.settings.token_operations_are_paused := false;
        return #ok("Token operations are resumed.");
    };

    public shared query func token_operation_status() : async Text {

        if (model.settings.token_operations_are_paused == false) {
            return "Token operations are enabled.";
        };

        let currentTime : Int = Time.now();
        if (currentTime > model.settings.token_operations_are_paused_expiration_time) {
            return "Token operations are enabled.";
        };

        let nanoSecondsToWait : Int = model.settings.token_operations_are_paused_expiration_time - currentTime;

        let totalSeconds = nanoSecondsToWait / 1000_000_000;
        let secondsToWait : Int = totalSeconds % 60;
        let minutesToWait : Int = ((totalSeconds -secondsToWait) / 60);
        let hoursToWait : Int = ((totalSeconds -secondsToWait - minutesToWait * 60) / (60 * 60));

        return "Token operations are paused until Hours: " #debug_show (Int.abs(hoursToWait)) # " / minutes: " #
        debug_show (Int.abs(minutesToWait)) # " / seconds: " #debug_show (Int.abs(secondsToWait));

    };

    public shared ({ caller }) func mint(args : T.TransactionTypes.Mint) : async T.TransactionTypes.TransferResult {        
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
               
        await* ExtendedToken.mint(token, args, caller, model.settings.archive_canisterIds, model);
    };

    public shared ({ caller }) func burn(args : T.TransactionTypes.BurnArgs) : async T.TransactionTypes.TransferResult {        
        if (cyclesAvailable() < Constants.TOKEN_CYCLES_NEEDED_FOR_OPERATIONS) {
            return #Err(#GenericError { error_code = 1234; message = "Not enough free Cycles available" });
        };
        await* ExtendedToken.burn(token, args, caller, model.settings.archive_canisterIds, model);
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

    public shared query func get_burned_amount() : async Nat {        
        token.burned_tokens;
    };

    public shared query func get_max_supply() : async Nat {        
        token.max_supply;
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

    public shared func get_transactions_by_index(startIndex:Nat, length:Nat) : async [T.TransactionTypes.Transaction] {
        await* ExtendedToken.get_transactions_by_index_directly(token, startIndex, length);
    };

    public shared func get_transactions_by_principal_count(principal:Principal) : async Nat {
        await* ExtendedToken.get_transactions_by_principal_count(token, principal);        
    };

    public shared func get_transactions_by_principal(principal:Principal, startIndex:Nat, length:Nat) : async [T.TransactionTypes.Transaction] {
        await* ExtendedToken.get_transactions_by_principal(token, principal, startIndex, length);        
    };

    // Additional functions not included in the ICRC1 standard
    public shared func get_transaction(i : T.TransactionTypes.TxIndex) : async ?T.TransactionTypes.Transaction {        
        await* ExtendedToken.get_transaction(token, i);
    };

    /// This function enables the timer to auto fill the dynamically created archive canisters
    public shared ({ caller }) func auto_topup_cycles_enable(minutes : ?Nat) : async Result.Result<Text, Text> {

        if (Account.user_is_owner_or_admin(caller, token) == false) {
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

        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };
        if (model.settings.autoTopupData.autoCyclesTopUpTimerId > 0 or model.settings.autoTopupData.autoCyclesTopUpEnabled == true) {
            cancelTimer(model.settings.autoTopupData.autoCyclesTopUpTimerId);
        };

        model.settings.autoTopupData.autoCyclesTopUpEnabled := false;
        #ok("Automatic cycles topUp for archive canisters is now disabled");
    };

    /// Show the status of the auto fill up timer settings
    public shared query func auto_topup_cycles_status() : async T.CanisterTypes.CanisterAutoTopUpDataResponse {

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

    private func token_operations_set_to_pause_internal<system>(minutes : Nat) {
        let minutesToUse : Nat = minutes;

        if (model.settings.token_operations_timer_id > 0 or model.settings.token_operations_are_paused == true) {
            cancelTimer(model.settings.token_operations_timer_id);
        };

        let timerSeconds = minutesToUse * 60;
        let nanoSecondsToUse : Nat = timerSeconds * 1000_000_000;
        let expirationTime : Int = Time.now() + nanoSecondsToUse;

        model.settings.token_operations_are_paused_expiration_time := expirationTime;
        model.settings.token_operations_are_paused := true;

        model.settings.token_operations_timer_id := setTimer<system>(
            #seconds timerSeconds,
            func() : async () {
                ignore await token_operation_continue<system>();
            },
        );
    };

    private func cyclesAvailable() : Nat {
        Cycles.balance();
    };

    private func auto_topup_cycles_enable_internal<system>() {
        if (model.settings.autoTopupData.autoCyclesTopUpTimerId > 0 or model.settings.autoTopupData.autoCyclesTopUpEnabled == true) {
            cancelTimer(model.settings.autoTopupData.autoCyclesTopUpTimerId);
        };

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



    system func inspect({
        caller : Principal;
        arg : Blob;
        msg : {
            #admin_add_admin_user : () -> Any;
            #admin_remove_admin_user : () -> Any;
            #all_canister_stats : () -> ();
            #auto_topup_cycles_disable : () -> ();
            #auto_topup_cycles_enable : () -> Any;
            #auto_topup_cycles_status : () -> ();
            #burn : () -> Any;
            #cycles_balance : () -> ();
            #deposit_cycles : () -> ();
            #feewhitelisting_add_principal : () -> Any;
            #feewhitelisting_get_list : () -> ();
            #feewhitelisting_remove_principal : () -> Any;
            #get_archive : () -> ();
            #get_archive_stored_txs : () -> ();
            #get_holders : () -> (Any, Any);
            #get_holders_count : () -> ();
            #get_total_tx : () -> ();
            #get_transaction : () -> Any;
            #get_transactions : () -> Any;
            #icrc1_balance_of : () -> Any;
            #icrc1_decimals : () -> ();
            #icrc1_fee : () -> ();
            #icrc1_metadata : () -> ();
            #icrc1_minting_account : () -> ();
            #icrc1_name : () -> ();
            #icrc1_supported_standards : () -> ();
            #icrc1_symbol : () -> ();
            #icrc1_total_supply : () -> ();
            #icrc1_transfer : () -> Any;
            #icrc2_allowance : () -> Any;
            #icrc2_approve : () -> Any;
            #icrc2_transfer_from : () -> Any;
            #list_admin_users : () -> ();
            #min_burn_amount : () -> ();
            #mint : () -> Any;
            #real_fee : () -> (Any, Any);
            #set_decimals : () -> Any;
            #set_fee : () -> Any;
            #set_logo : () -> Any;
            #set_min_burn_amount : () -> Any;
            #set_name : () -> Any;
            #set_symbol : () -> Any;
            #token_operation_continue : () -> ();
            #token_operation_pause : () -> Any;
            #token_operation_status : () -> ();
            #tokens_amount_upscale : () -> Any;
            #tokens_amount_downscale : () -> Any;
            #get_burned_amount : () -> ();
            #get_max_supply : () -> ();
            #backup : () -> (TypesBackupRestore.BackupParameter);
            #restore : () -> Any;
            #get_transactions_by_index : () -> (Any, Any);
            #get_transactions_by_principal_count: () -> Any;
            #get_transactions_by_principal: () -> (Any, Any,Any);   
            #get_allowance_list:() -> Any;
            #get_token_maindata: () -> ();                
        };
    }) : Bool {
     
        if (model.settings.token_operations_are_paused) {

            //if (Account.user_is_owner_or_admin(caller, token) == false and caller != Principal.fromActor(this)) {
            if (Account.user_is_owner_or_admin(caller, token) == true and caller != Principal.fromActor(this)) {
                switch (msg) {
                    case ((#token_operation_continue _)) {
                        return true;
                    };
                    case ((#token_operation_status _)) {
                        return true;
                    };
                    case ((#token_operation_pause _)) {
                        return true;
                    };
                    case ((#backup _)) {
                        return true;
                    };
                    case ((#restore _)) {
                        return true;
                    };
                    case _ {
                        return false;
                    };
                };
                return false;
            };
            return false;
        };
        return true;
    };


    

};
