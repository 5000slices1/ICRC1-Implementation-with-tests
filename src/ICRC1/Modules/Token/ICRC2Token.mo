import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import SB "mo:StableBuffer/StableBuffer";
import ICRC1 "ICRC1Token";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Itertools "mo:itertools/Iter";
import Trie "mo:base/Trie";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import T "../../Types/Types.All";
import Constants "../../Types/Types.Constants";
import Account "Account/Account";
import Region "mo:base/Region";
import Utils "Utils/Utils";
import Model "../../Types/Types.Model";
import HashList "mo:memory-hashlist";


/// The ICRC2 methods implementation
module {

    private type TokenData = T.TokenTypes.TokenData;

    public func icrc2_approve(
        caller : Principal,
        approveArgs : T.TransactionTypes.ApproveArgs,
        token : TokenData,
        model:Model.Model
    ) : async T.TransactionTypes.ApproveResponse {

        // if (Principal.isAnonymous(caller)){
        //     throw Error.reject("anonymous user is not allowed to transfer funds");
        // };

        // check if caller has enough token amount for the approval fee
        

        let from = {
            owner = caller;
            subaccount = approveArgs.from_subaccount;
        };

       

        let tx_kind = #approve;

        //let tx_req = Utils.create_approve_req(args, caller, tx_kind);


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


    // private func create_approve_req(
    //     args : T.TransactionTypes.ApproveArgs,
    //     owner : Principal,
    //     tx_kind : T.TransactionTypes.OperationKind,
    // ) : T.ApproveTxRequest {

    //     let from = {
    //         owner;
    //         subaccount = args.from_subaccount;
    //     };

    //     let to = {
    //         owner = args.spender;
    //         subaccount = null;
    //     };

    //     let encoded = {
    //         from = Account.encode(from);
    //         to = Account.encode(to);
    //     };

    //     {
    //         kind = tx_kind;
    //         from = from;
    //         spender = to;
    //         amount = args.amount;
    //         expires_at = args.expires_at;
    //         fee = args.fee;
    //         memo = args.memo;
    //         created_at_time = args.created_at_time;
    //         expected_allowance = args.expected_allowance;
    //         // args with kind = #approve;
    //         encoded;
    //     };
    // };


};
