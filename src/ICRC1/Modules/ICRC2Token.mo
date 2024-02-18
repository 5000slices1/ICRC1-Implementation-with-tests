import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import SB "mo:StableBuffer/StableBuffer";
import ICRC1 "../Modules/ICRC1Token";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Itertools "mo:itertools/Iter";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import T "../Types/Types.All";
import Constants "../Types/Types.Constants";
import Account "../Modules/Account";
import Region "mo:base/Region";
import Utils "../Modules/Utils";

module {

    private type TokenData = T.TokenTypes.TokenData;

    public func icrc2_approve(
        caller : Principal,
        approveArgs : T.TransactionTypes.ApproveArgs,
        token : TokenData,
    ) : async T.TransactionTypes.ApproveResponse {

        
        return #Ok(0);
    };

    public func icrc2_allowance(
        allowanceArgs : T.TransactionTypes.AllowanceArgs,
        token : TokenData,
    ) : async T.TransactionTypes.Allowance {
        let dummyResult : T.TransactionTypes.Allowance = {
            allowance = 0;
            expires_at = null;
        };
        return dummyResult;
    };

    public func icrc2_transfer_from(
        caller : Principal,
        transferFromArgs : T.TransactionTypes.TransferFromArgs,
        token : TokenData,
    ) : async T.TransactionTypes.TransferFromResponse {

        return #Ok(0);
    };

};
