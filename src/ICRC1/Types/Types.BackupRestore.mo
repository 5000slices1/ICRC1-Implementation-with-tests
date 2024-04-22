import Token "Types.Token";
import CommonTypes "Types.Common";
import TypesAccount "Types.Account";
import TypesTransaction "Types.Transaction";

module {

  public type BackupCommonTokenData = {

    name : Text;
    symbol : Text;
    decimals : Nat8;
    defaultFee : CommonTypes.Balance;
    logo : Text;
    max_supply : CommonTypes.Balance;
    minted_tokens : CommonTypes.Balance;
    minting_allowed : Bool;
    burned_tokens : CommonTypes.Balance;
    minting_account : TypesAccount.Account;
    supported_standards : [Token.SupportedStandard];
    transaction_window : Nat;
    min_burn_amount : CommonTypes.Balance;
    permitted_drift : Nat;
    feeWhitelistedPrincipals : TypesAccount.PrincipalsWhitelistedFees;
    tokenAdmins : TypesAccount.AdminPrincipals;

    //transactions : [TypesTransaction.Transaction];
    //archive : ArchiveData;
    //accounts : AccountBalances;
  };

  public type BackupType = {
    #tokenCommonData;
    #tokenAccounts;
    #tokenFeeWhitelistedPrincipals;
    #tokenTokenAdmins;
    #tokenTransactionsBuffer;

  };

  public type BackupInfoChunk = {
    dataType : BackupType;
    bytesLength : Nat;
    isLastChunkForThisType : Bool;
  };

};
