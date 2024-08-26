import CommonTypes "Types.Common";
import TypesAccount "Types.Account";

module {

  public type BackupCommonTokenData = {

    // The name of the token.
    name : Text;
    
    // The symbol of the token.
    symbol : Text;
    
    // The number of decimal places the token uses.
    decimals : Nat8;
    
    // The default transaction fee for the token.
    fee : CommonTypes.Balance;
    
    // The logo of the token.
    logo : Text;
    
    // The maximum supply of the token.
    max_supply : CommonTypes.Balance;
    
    // The total number of tokens that have been minted.
    minted_tokens : CommonTypes.Balance;
    
    // Indicates whether minting new tokens is allowed.
    minting_allowed : Bool;
    
    // The total number of tokens that have been burned.
    burned_tokens : CommonTypes.Balance;
    
    // The account authorized to mint new tokens.
    minting_account : TypesAccount.Account;
    
    // The list of supported standards for the token.
    supported_standards : [CommonTypes.SupportedStandard];
    
    // The time window for transactions.
    transaction_window : Nat;
    
    // The minimum amount of tokens that can be burned in a single transaction.
    min_burn_amount : CommonTypes.Balance;
    
    // The permitted drift for transactions.
    permitted_drift : Nat;
    
    // The list of principals that are whitelisted for fee exemptions.
    feeWhitelistedPrincipals : TypesAccount.PrincipalsWhitelistedFees;
    
    // The list of principals that are token administrators.
    tokenAdmins : TypesAccount.AdminPrincipals;
  };

  // Defines the type of data that can be backed up.
  public type BackupType = {
      // Common data related to the token.
      #tokenCommonData;
      // Account data related to the token.
      #tokenAccounts;
      // Buffer for token transactions.
      #tokenTransactionsBuffer;
  };
  
  // Information required to restore data from a backup.
  public type RestoreInfo = {
      // The type of data being restored.
      dataType : BackupType;
      // Indicates if this is the first chunk of the data.
      isFirstChunk : Bool;
      // The actual data bytes to be restored.
      bytes : [Nat8];
  };
  
  // Parameters required to perform a backup.
  public type BackupParameter = {
      // The type of data to be backed up.
      backupType : BackupType;
      // The current index in the backup process (optional).
      currentIndex : ?Nat;
      // The total number of chunks in the backup process (optional).
      chunkCount : ?Nat;
  };

};
