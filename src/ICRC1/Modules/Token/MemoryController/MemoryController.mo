
import Hash "mo:base/Hash";
import T "../../../Types/Types.All";
import ModelType "../../../Types/Types.Model";

import HashList "mo:memory-hashlist";
import HashListType "mo:memory-hashlist/modules/libMemoryHashList";

import HashTable "mo:memory-hashtable";
import HashTableType "mo:memory-hashtable/modules/memoryHashTable";

module {

/// Organizer and Controller for the stable vars and memory related usages (hashlist, hashtable)
public class MemoryController(modelToUse:ModelType.Model){

    public var model:ModelType.Model = modelToUse;

    public let databaseController:DatabaseController = DatabaseController(model.databaseStorages);


};

public class DatabaseController(databaseStorages:ModelType.DatabaseStorages){
    private let hashList:HashListType.libMemoryHashList = HashList.MemoryHashList(databaseStorages.memoryDatabaseForHashList);
    private let hashTable:HashTableType.MemoryHashTable = HashTable.MemoryHashTable(databaseStorages.memoryDatabaseForHashTable);



};

};
