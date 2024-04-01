
import Hash "mo:base/Hash";
import T "../../../Types/Types.All";
import ModelType "../../../Types/Types.Model";

import HashList "mo:memory-hashlist";
import HashListType "mo:memory-hashlist/modules/libMemoryHashList";

import HashTable "mo:memory-hashtable";
import HashTableType "mo:memory-hashtable/modules/memoryHashTable";
import DatabaseController "Database/DatabaseController";

module {

/// Organizer and Controller for the stable vars and memory related usages (hashlist, hashtable)
public class MemoryController(modelToUse:ModelType.Model){

    public var model:ModelType.Model = modelToUse;

    public let databaseController:DatabaseController.DatabaseController 
        = DatabaseController.DatabaseController(model.databaseStorages);


};



};
