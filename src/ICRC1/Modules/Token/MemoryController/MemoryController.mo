import ModelType "../../../Types/Types.Model";
import DatabaseController "Database/DatabaseController";

module {

    /// Organizer and Controller for the stable vars and memory related usages (hashlist, hashtable)
    public class MemoryController(modelToUse : ModelType.Model) {

        public var model : ModelType.Model = modelToUse;

        public let databaseController : DatabaseController.DatabaseController = DatabaseController.DatabaseController(model.databaseStorages);

    };

};
