import HashList "mo:memory-hashlist";
import HashTable "mo:memory-hashtable";
import Int "mo:base/Int";
import T "Types.All";


/// Model related types
module {

    public type DatabaseStorages = {

        memoryDatabaseForHashList : HashList.MemoryStorage;
        memoryDatabaseForHashTable : HashTable.MemoryStorage;

    };

    public type TokenMainOperationsMode = {
        #normal;
        #operationsPaused;              
    };

    public type TokenSubOperationsMode = {
        #idle;
        #requested:(Principal, Int);
        #approved;
        #progressing;
        #completed;
    };


     public type TokenScalingOperationsMode = {
        #idle;
        #requested:(Principal, Int, Nat8);        
        #progressing:Nat8;        
    };

    public type BackupInitState = {
        #idle;
        #initiated:(startTime:Nat);        
    };

    public type BackupStateInfo = {
        var state:BackupInitState;
    };

    
    public type Settings = {
        var wasInitializedWithArguments : Bool;
        var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds;
        var tokenCanisterId : Principal;
        var autoTopupData : T.CanisterTypes.CanisterAutoTopUpData;
        
        // set as var, so during testing we can change these values
        var ARCHIVE_MAX_MEMORY:Nat; 
        var ARCHIVE_MAX_HEAP_SIZE:Nat;

        // Pause the token operations. 
        // This is useful for update/upgrade, backup/restore, token scaling, etc. operations...)        
        var token_operations_are_paused:Bool;
        
        // Maximum time the token operations will be suspended. 
        // (This is to make sure that the operations will not be suspended forever. 
        //  For example in the case that the user forgot to disable the supension)
        var token_operations_are_paused_expiration_time:Int;
        
        var tokens_operation_mode:TokenMainOperationsMode;
        var tokens_upscaling_mode:TokenScalingOperationsMode;
        var tokens_downscaling_mode:TokenScalingOperationsMode;
        var tokens_data_restore_mode:TokenSubOperationsMode;


        //-------------------------------------------------------------------        
        // Timer id's

        // The timer-id for the paused token operations expiration time
        var token_operations_timer_id:Nat;

        // Timer id for the ongoing token amount upscale process
        var tokens_upscaling_timer_id:Nat;

        // Timer id for the ongoing token amount downscale process
        var tokens_downscaling_timer_id:Nat;

        // Timer id for the ongoing token restoring process. (Restore from previous backup data)
        var tokens_restore_data_timer_id:Nat;
        //-------------------------------------------------------------------

        //-------------------------------------------------------------------
        // Backup/Restore
        backupStateInfo:BackupStateInfo;

        //-------------------------------------------------------------------
        
    };

    public type Model = {

        settings : Settings;
        databaseStorages : DatabaseStorages;

    };

};
