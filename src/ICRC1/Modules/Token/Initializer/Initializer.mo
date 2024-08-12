import TokenTypes "../../../Types/Types.Token";
import StableBuffer "mo:StableBuffer/StableBuffer";
import Nat8 "mo:base/Nat8";
import List "mo:base/List";
import StableBufferExtended "../Utils/Utils";
import T "../../../Types/Types.All";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Itertools "mo:itertools/Iter";
import StableTrieMap "mo:StableTrieMap";
import HashList "mo:memory-hashlist";

import HashTable "mo:memory-hashtable";
import { ConstantTypes } = "../../../Types/Types.All";
import Account "../Account/Account";
import Model "../../../Types/Types.Model";
import TypesBackupRestore "../../../Types/Types.BackupRestore";
import CommonTypes "../../../Types/Types.Common";

module {

    private type InitArgs = TokenTypes.InitArgs;
    private type MetaDatum = TokenTypes.MetaDatum;
    private let SB = StableBufferExtended.SB;
    private type SupportedStandard = CommonTypes.SupportedStandard;
    private type Balance = T.Balance;
    private type Subaccount = T.AccountTypes.Subaccount;
    private type AccountBalances = T.AccountTypes.AccountBalances;

    public func init_model() : Model.Model {

        let result : Model.Model = {

            settings : Model.Settings = {
                var wasInitializedWithArguments : Bool = false;
                var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds = {
                    var canisterIds = List.nil<Principal>();
                };
                var tokenCanisterId : Principal = Principal.fromText("aaaaa-aa");

                var autoTopupData : T.CanisterTypes.CanisterAutoTopUpData = {
                    var autoCyclesTopUpEnabled = false;
                    var autoCyclesTopUpMinutes : Nat = 60 * 12; //12 hours
                    var autoCyclesTopUpTimerId : Nat = 0;
                    var autoCyclesTopUpOccuredNumberOfTimes : Nat = 0;
                };

                var ARCHIVE_MAX_MEMORY:Nat = ConstantTypes.ARCHIVE_MAX_MEMORY;
                var ARCHIVE_MAX_HEAP_SIZE:Nat = ConstantTypes.ARCHIVE_MAX_HEAP_SIZE;
                  
                var token_operations_are_paused:Bool = false;                
                var token_operations_are_paused_expiration_time:Int = 0;

                var tokens_operation_mode:Model.TokenMainOperationsMode = #normal;
                var tokens_upscaling_mode:Model.TokenScalingOperationsMode = #idle;
                var tokens_downscaling_mode:Model.TokenScalingOperationsMode = #idle;
                var tokens_data_restore_mode:Model.TokenSubOperationsMode = #idle;

                var token_operations_timer_id:Nat = 0;
                var tokens_upscaling_timer_id:Nat = 0;
                var tokens_downscaling_timer_id:Nat = 0;
                var tokens_restore_data_timer_id:Nat = 0;

                backupStateInfo:Model.BackupStateInfo = {
                    var state:Model.BackupInitState = #idle;
                };
            };

            databaseStorages : Model.DatabaseStorages = {
                memoryDatabaseForHashList = HashList.get_new_memory_storage(2);
                memoryDatabaseForHashTable : HashTable.MemoryStorage = HashTable.get_new_memory_storage(0);
            };
        };

        return result;

    };

    /// Creates a Stable Buffer with the default metadata and returns it.
    public func init_metadata(args : InitArgs) : StableBuffer.StableBuffer<MetaDatum> {
        let metadata = SB.initPresized<MetaDatum>(5);
        SB.add(metadata, ("icrc1:fee", #Nat(args.fee)));
        SB.add(metadata, ("icrc1:name", #Text(args.name)));
        SB.add(metadata, ("icrc1:symbol", #Text(args.symbol)));
        SB.add(metadata, ("icrc1:decimals", #Nat(Nat8.toNat(args.decimals))));
        SB.add(metadata, ("icrc1:minting_allowed", #Text(debug_show (args.minting_allowed))));
        SB.add(metadata, ("icrc1:logo", #Text(args.logo)));

        metadata;
    };

    /// Creates a Stable Buffer with the default supported standards and returns it.
    public func init_standards() : StableBuffer.StableBuffer<SupportedStandard> {
        let standards = SB.initPresized<SupportedStandard>(4);
        SB.add(standards, icrc1_standard);
        SB.add(standards, icrc2_standard);

        standards;
    };

    /// Initialize a new ICRC-1 token
    public func tokenInit(args : T.TokenTypes.InitArgs) : T.TokenTypes.TokenData {

        //With this we map the fields of 'args' to direct variables.
        //So for example we do not need to use 'args.minting_account' and we can use 'minting_account' directly.
        let {
            name;
            symbol;
            decimals;
            fee;
            logo;
            minting_account;
            max_supply;
            initial_balances;
            min_burn_amount;
            minting_allowed;
        } = args;

        var _burned_tokens = 0;
        var permitted_drift_value = 60_000_000_000; // 1 minute
        var transaction_window_value = 86_400_000_000_000; //24 hours

        if (not Account.validate(minting_account)) {
            Debug.trap("minting_account is invalid");
        };

        let accounts : AccountBalances = StableTrieMap.new();

        var _minted_tokens = _burned_tokens;

        for ((i, (account, balance)) in Itertools.enumerate(initial_balances.vals())) {

            if (not Account.validate(account)) {
                Debug.trap(
                    "Invalid Account: Account at index " # debug_show i # " is invalid in 'initial_balances'"
                );
            };

            let encoded_account = Account.encode(account);

            StableTrieMap.put(
                accounts, //Dictionnary to use
                Blob.equal, //compare function
                Blob.hash, //hash function
                encoded_account, //key
                balance, //value
            );

            _minted_tokens += balance;
        };

        let result : T.TokenTypes.TokenData = {
            var name = name;
            var symbol = symbol;
            var decimals = decimals;
            var defaultFee = fee;
            var logo = logo;
            var max_supply = max_supply;
            var minted_tokens = _minted_tokens;
            var burned_tokens = _burned_tokens;
            var min_burn_amount = min_burn_amount;
            var minting_account = minting_account;
            var minting_allowed = minting_allowed;
            accounts;
            var feeWhitelistedPrincipals = List.nil<Principal>();
            var tokenAdmins = List.nil<Principal>();
            metadata = init_metadata(args);
            supported_standards = init_standards();            
            transactions = SB.initPresized(ConstantTypes.MAX_TRANSACTIONS_IN_LEDGER);
            var permitted_drift = permitted_drift_value;
            var transaction_window = transaction_window_value;
            archive = {
                var canister = actor ("aaaaa-aa");
                var stored_txs = 0;
            };
        };

        return result;
    };

    private let icrc1_standard : SupportedStandard = {
        name = "ICRC-1";
        url = "https://github.com/dfinity/ICRC-1";
    };

    private let icrc2_standard : SupportedStandard = {
        name = "ICRC-2";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-2";
    };

};
