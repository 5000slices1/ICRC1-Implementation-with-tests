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

    public type Settings = {
        var wasInitializedWithArguments : Bool;
        var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds;
        var tokenCanisterId : Principal;
        var autoTopupData : T.CanisterTypes.CanisterAutoTopUpData;
        
        // set as var, so during testing we can change these values
        var ARCHIVE_MAX_MEMORY:Nat; 
        var ARCHIVE_MAX_HEAP_SIZE:Nat;

        // Pause the token operations. (This is useful if we plan to do some update/upgrade etc..)        
        var token_operations_are_paused:Bool;
        
        // Maximum time the token operations will be suspended. 
        // (This is to make sure that the operations will not be suspended forever. 
        //  For example in the case that the user forgot to disable the supension)
        var token_operations_are_paused_expiration_time:Int;

        var token_operations_timer_id:Nat;
    };

    public type Model = {

        settings : Settings;
        databaseStorages : DatabaseStorages;

    };

};
