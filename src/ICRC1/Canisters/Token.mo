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
import T "../Types/Types.All";
import Constants "../Types/Types.Constants";
import Account "../Modules/Token/Account/Account";
import Initializer "../Modules/Token/Initializer/Initializer";
import Model "../Types/Types.Model";
import Converters = "../Modules/Converters/Converters";
import MemoryController "../Modules/Token/MemoryController/MemoryController";



/// The actor class for the main token
shared ({ caller = _owner }) actor class Token(init_args : ?T.TokenTypes.TokenInitArgs) : async T.TokenTypes.FullInterface = this {

    private stable var model : Model.Model = Initializer.init_model();

    //Convert argument, because 'init_args' can now be null, in case of upgrade scenarios. ('dfx deploy')
    let init_arguments : ?T.TokenTypes.InitArgs = Converters.ConvertTokenInitArgs(init_args, model, _owner);

    private stable let token : T.TokenTypes.TokenData = switch (init_arguments) {
        case null {
            Debug.trap("Initialize token with no arguments not allowed.");
        };
        case (?initArgsNotNull) Initializer.tokenInit(initArgsNotNull);
    };

    private let memoryController : MemoryController.MemoryController = MemoryController.MemoryController(model);

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

    public shared query func icrc1_supported_standards() : async [T.TokenTypes.SupportedStandard] {
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

    /// Show the token holders
    public shared query func get_holders_count() : async Nat {
        SlicesToken.get_holders_count(token);
    };

    /// Get list of the holders
    /// The returned list can contain maximum 5000 entries. Therefore the additional 'index' and 'count' parameter in case
    /// there are more than 5000 entries available.
    public shared query func get_holders(index : ?Nat, count : ?Nat) : async [T.AccountTypes.AccountBalanceInfo] {
        SlicesToken.get_holders(token, index, count);
    };


    // -------------------------------------------------------------------------------------------

    // ------------------------------------------------------------------------------------------
    // Additional token functions


    /// Pause token operations. This is useful if we do some time consuming operations like update/upgrade or token scaling...
    public shared ({ caller }) func token_operation_pause<system>(minutes : ?Nat):async Result.Result<Text, Text>{        
        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };

        let minutesToUse : Nat = switch (minutes) {
            case (?minutes) minutes;
            case (null) 15; // 15 minutes as default
        };

        let timerSeconds = minutesToUse * 60;
        let nanoSecondsToUse:Nat = timerSeconds * 1000_000_000;
        let expirationTime:Int = Time.now() + nanoSecondsToUse;

        model.settings.token_operations_are_paused_expiration_time:= expirationTime;
        model.settings.token_operations_are_paused:= true;       
        
        if (model.settings.token_operations_are_paused == true){
            cancelTimer(model.settings.token_operations_timer_id);
        };

        model.settings.token_operations_timer_id:= setTimer<system>(
            #seconds timerSeconds,
            func() : async () {
                ignore await token_operation_continue<system>();
            },
        );


        return #ok("Token operations are paused.");
    };

    // The token operations will resume again....
    public shared ({ caller }) func token_operation_continue():async Result.Result<Text, Text>{
        
        if (Account.user_is_owner_or_admin(caller, token) == false) {
            return #err("Unauthorized: Only minting account or admin can call this function..");
        };
        
        if (model.settings.token_operations_are_paused == true){
            cancelTimer(model.settings.token_operations_timer_id);
        };
        model.settings.token_operations_are_paused:= false;  
        return #ok("Token operations are resumed.");
    };

    public shared query func token_operation_status():async Text{
        
        if (model.settings.token_operations_are_paused == false){
            return "Token operations are enabled.";
        };

        let currentTime:Int = Time.now();
        if (currentTime > model.settings.token_operations_are_paused_expiration_time){
            return "Token operations are enabled.";
        };

        return "Token operations are paused.";

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
        if (model.settings.autoTopupData.autoCyclesTopUpEnabled == true){
            cancelTimer(model.settings.autoTopupData.autoCyclesTopUpTimerId);
        };

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
        if ( model.settings.autoTopupData.autoCyclesTopUpEnabled == true){
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

    system func inspect(
     {
       caller : Principal;
       arg : Blob;
       msg : {
         #admin_add_admin_user : () -> Principal;
        #admin_remove_admin_user : () -> Principal;
        #all_canister_stats : () -> ();
        #auto_topup_cycles_disable : () -> ();
        #auto_topup_cycles_enable : () -> ?Nat;
        #auto_topup_cycles_status : () -> ();
        #burn : () -> T.TransactionTypes.BurnArgs;        
        #cycles_balance : () -> ();
        #deposit_cycles : () -> ();
        #feewhitelisting_add_principal : () -> Principal;
        #feewhitelisting_get_list : () -> ();
        #feewhitelisting_remove_principal : () -> Principal;
        #get_archive : () -> ();
        #get_archive_stored_txs : () -> ();
        #get_holders : () -> (?Nat, ?Nat);
        #get_holders_count : () -> ();
        #get_total_tx : () -> ();
        #get_transaction : () -> T.TransactionTypes.TxIndex;
        #get_transactions : () -> T.TransactionTypes.GetTransactionsRequest;
        #icrc1_balance_of : () -> T.AccountTypes.Account;
        #icrc1_decimals : () -> ();
        #icrc1_fee : () -> ();
        #icrc1_metadata : () -> ();
        #icrc1_minting_account : () -> ();
        #icrc1_name : () -> ();
        #icrc1_supported_standards : () -> ();
        #icrc1_symbol : () -> ();
        #icrc1_total_supply : () -> ();
        #icrc1_transfer : () -> T.TransactionTypes.TransferArgs;
        #icrc2_allowance : () -> T.TransactionTypes.AllowanceArgs;
        #icrc2_approve : () -> T.TransactionTypes.ApproveArgs;
        #icrc2_transfer_from : () -> T.TransactionTypes.TransferFromArgs;
        #list_admin_users : () -> ();
        #min_burn_amount : () -> ();
        #mint : () -> T.TransactionTypes.Mint;    
        #real_fee : () -> (Principal, Principal);
        #set_decimals : () -> Nat8;
        #set_fee : () -> T.Balance;
        #set_logo : () -> Text;
        #set_min_burn_amount : () -> T.Balance;
        #set_name : () -> Text;
        #set_symbol : () -> Text;
        #token_operation_continue : () -> ();
        #token_operation_pause: () -> ?Nat;    
        #token_operation_status : () -> ();        
       }
     }) : Bool {

        if (model.settings.token_operations_are_paused){
            let currentTime:Int = Time.now();
            
            if (currentTime <= model.settings.token_operations_are_paused_expiration_time){                
                switch(msg){
                    case ((#token_operation_continue _)){
                        return true;
                    };
                    case ((#token_operation_status _)){
                        return true;
                    };
                    case ((#token_operation_pause _)){
                        return true;
                    };
                    case _ {                        
                        return false;
                    };                    
                };                    
                return false;            
            };

        };
        return true;
     };
    
};
