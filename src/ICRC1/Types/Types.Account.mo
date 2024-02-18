import STMap "mo:StableTrieMap";
import Principal "mo:base/Principal";
import List "mo:base/List";
import CommonTypes "Types.Common"

module{
    
    ///The blob encoded account
    public type EncodedAccount = Blob;

    ///Sub-account as blob
    public type Subaccount = Blob;

    ///The Account-Balances holds the balances for each accout. 
    ///This type is included in the token-data type itself.    
    public type AccountBalances = STMap.StableTrieMap<EncodedAccount, CommonTypes.Balance>;

    public type PrincipalsWhiteListedFees = List.List<Principal>;

    public type AdminPrincipals = List.List<Principal>;
    
    ///For Response
    public type ParseError = {
        #malformed : Text;
        #not_canonical;
        #bad_checksum;
    };

    ///Definition of account-type 
    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    ///This type is the response-type for the function 'get_holders' in token.mo
    public type AccountBalanceInfo = {
        account: Account;
        balance: CommonTypes.Balance;
    };
};
