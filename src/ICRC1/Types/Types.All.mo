import T_CommonTypes "Types.Common";
import T_AccountTypes "Types.Account";
import T_ArchiveTypes "Types.Archive";
import T_TokenTypes "Types.Token";
import T_TransactionTypes "Types.Transaction";
import T_ConstantTypes "Types.Constants";
import T_CanisterTypes "Types.Canister";

module{

    // Define a public type alias for Value from T_CommonTypes.
    public type Value = T_CommonTypes.Value;
    
    // Define a public type alias for Balance from T_CommonTypes.
    public type Balance = T_CommonTypes.Balance;
    
    // Import and alias common types from T_CommonTypes.
    public let CommonTypes = T_CommonTypes;
    
    // Import and alias account types from T_AccountTypes.
    public let AccountTypes = T_AccountTypes;
    
    // Import and alias archive types from T_ArchiveTypes.
    public let ArchiveTypes = T_ArchiveTypes;
    
    // Import and alias token types from T_TokenTypes.
    public let TokenTypes = T_TokenTypes;
    
    // Import and alias transaction types from T_TransactionTypes.
    public let TransactionTypes = T_TransactionTypes;
    
    // Import and alias constant types from T_ConstantTypes.
    public let ConstantTypes = T_ConstantTypes;
    
    // Import and alias canister types from T_CanisterTypes.
    public let CanisterTypes = T_CanisterTypes;
    
        
};
