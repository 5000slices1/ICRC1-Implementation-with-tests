import HashList "mo:memory-hashlist";
import HashTable "mo:memory-hashtable";
import T "Types.All";

/// Model related types
module {

public type DatabaseStorages = {

    memoryDatabaseForHashList:HashList.MemoryStorage;
    memoryDatabaseForHashTable:HashTable.MemoryStorage; 

};

public type Settings = {
    var wasInitializedWithArguments : Bool;
    var archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds;
    var tokenCanisterId : Principal ;
    var autoTopupData : T.CanisterTypes.CanisterAutoTopUpData;
};

public type Model = {

    settings:Settings;
    databaseStorages:DatabaseStorages;



};



};