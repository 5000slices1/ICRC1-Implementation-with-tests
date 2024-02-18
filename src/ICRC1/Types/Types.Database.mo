import Time "mo:base/Time";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import StableTrieMap "mo:StableTrieMap";
import Region "mo:base/Region";
import T "../Types/Types.All";

module{

    public type IndexBasedDatabaseItem = {
        bytes : Region;
        var bytes_count : Nat64;

        elems : Region;
        var elems_count : Nat64;
    };

    public type DatabaseAccount={
        DbAccount:T.AccountTypes.Account;
        DbBalance:T.CommonTypes.Balance;
    }

};