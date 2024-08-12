import T "../../Types/Types.All";
import TypesModel "../../Types/Types.Model";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Itertools "mo:itertools/Iter";
import TypesConstants "../../Types/Types.Constants";
import Account "../Token/Account/Account";
import Utils "../Token/Utils/Utils";
import TypesToken "../../Types/Types.Token";
import TypesBackup "../../Types/Types.BackupRestore";
import TypesAccount "../../Types/Types.Account";
import TypesCommon "../../Types/Types.Common";


module {

    private type TokenData = TypesToken.TokenData;
    let { SB } = Utils;

    public func ConvertTokenInitArgs(
        init_arguments : ?T.TokenTypes.TokenInitArgs,
        model : TypesModel.Model,
        canisterOwner : Principal,
    ) : ?T.TokenTypes.InitArgs {
        if (init_arguments == null) {

            if (model.settings.wasInitializedWithArguments == false) {
                let infoText : Text = "ERROR! Empty argument in dfx deploy is only allowed for canister updates";
                Debug.print(infoText);
                Debug.trap(infoText);
            };
            return null;
        };

        if (model.settings.wasInitializedWithArguments == true) {
            let infoText : Text = "ERROR! Re-initializing is not allowed";
            Debug.print(infoText);
            Debug.trap(infoText);
        } else {

            var argsToUse : T.TokenTypes.TokenInitArgs = switch (init_arguments) {
                case null return null; // should never happen
                case (?tokenArgs) tokenArgs;
            };

            let icrc1_args : T.TokenTypes.InitArgs = {
                argsToUse with minting_account = Option.get(argsToUse.minting_account, { owner = canisterOwner; subaccount = null });
            };

            if (icrc1_args.initial_balances.size() < 1) {
                if (icrc1_args.minting_allowed == false) {
                    let infoText : Text = "ERROR! When minting feature is disabled at least one initial balances account is needed.";
                    Debug.print(infoText);
                    Debug.trap(infoText);
                };
            } else {

                for ((i, (account, balance)) in Itertools.enumerate(icrc1_args.initial_balances.vals())) {

                    if (account.owner == icrc1_args.minting_account.owner) {
                        let infoText : Text = "ERROR! Minting account was specified in initial balances account. This is not allowed.";
                        Debug.print(infoText);
                        Debug.trap(infoText);

                    };
                };
            };

            //Now check the balance of cycles available:
            let amount = Cycles.balance();
            if (amount < TypesConstants.TOKEN_INITIAL_CYCLES_REQUIRED) {
                let missingBalance : Nat = TypesConstants.TOKEN_INITIAL_CYCLES_REQUIRED - amount;
                let infoText : Text = "\r\nERROR! At least " #debug_show (TypesConstants.TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED)
                # " cycles are needed for deployment. \r\n "
                # "- Available cycles: " #debug_show (amount) # "\r\n"
                # "- Missing cycles: " #debug_show (missingBalance) # "\r\n"
                # " -> You can use the '--with-cycles' command in dfx deploy. \r\n"
                # "    For example: \r\n"
                # "    'dfx deploy icrc1 --with-cycles 3000000000000'";
                Debug.print(infoText);
                Debug.trap(infoText);
            };

            model.settings.wasInitializedWithArguments := true;
            return Option.make(icrc1_args);
        };
    };

    // Formats the different operation arguments into
    // an `ApproveRequest`, an internal type to access fields easier.
    public func create_approve_req(
        args : T.TransactionTypes.ApproveArgs,
        owner : Principal,
    ) : T.TransactionTypes.ApproveRequest {

        let from = {
            owner;
            subaccount = args.from_subaccount;
        };

        let encoded = {
            from = Account.encode(from);
            spender = Account.encode(args.spender);
        };

        {
            args with from = from;
            encoded;
        };
    };

    // Formats the different operation arguements into
    // a `TransactionFromRequest`, an internal type to access fields easier.
    public func create_transfer_from_req(
        args : T.TransactionTypes.TransferFromArgs,
        owner : Principal,
        token : TokenData,
        tx_kind : T.TransactionTypes.TxKind,
    ) : T.TransactionTypes.TransactionFromRequest {
        let spender = { owner; subaccount = args.spender_subaccount };
        var transfer_args : T.TransactionTypes.TransferArgs = {
            args with from_subaccount = null
        };

        var transfer_from_args : T.TransactionTypes.TransactionRequest = Utils.create_transfer_req(transfer_args, owner, tx_kind, token);

        let result : T.TransactionTypes.TransactionFromRequest = {
            transfer_from_args with encoded = {
                from = Account.encode(args.from);
                to = Account.encode(args.to);
                spender = Account.encode(spender);
            };
            fee = ?transfer_from_args.fee;
            from = args.from;
            spender;
        };

        return result;
    };

    //--------------------------------------------------------------------------------
    // Converters for backup and restore

    public func ConvertToTokenMainDataNat8Array(token:T.TokenTypes.TokenData):[Nat8]{        
        let resultAsType:TypesBackup.BackupCommonTokenData = {
   
            name : Text = token.name;   
            symbol : Text = token.symbol;       
            decimals : Nat8 = token.decimals;     
            defaultFee : TypesCommon.Balance = token.defaultFee;
            logo : Text = token.logo;    
            max_supply : TypesCommon.Balance = token.max_supply;
            minted_tokens : TypesCommon.Balance = token.minted_tokens; 
            minting_allowed : Bool = token.minting_allowed;
            burned_tokens : TypesCommon.Balance = token.burned_tokens;
            minting_account : TypesAccount.Account = token.minting_account; 
            supported_standards : [TypesCommon.SupportedStandard] = SB.toArray(token.supported_standards);      
            transaction_window : Nat = token.transaction_window;        
            min_burn_amount : TypesCommon.Balance = token.min_burn_amount;      
            permitted_drift : Nat = token.permitted_drift;
            feeWhitelistedPrincipals : TypesAccount.PrincipalsWhitelistedFees = token.feeWhitelistedPrincipals;
            tokenAdmins : TypesAccount.AdminPrincipals = token.tokenAdmins;
                //transactions : [TypesTransaction.Transaction];       
                //archive : ArchiveData;      
                //accounts : AccountBalances;        
        };

        let resultAsBlob:Blob = to_candid(resultAsType);
        return Blob.toArray(resultAsBlob);                 
    };

    public func ConvertToTokenMainDataFromNat8Array(array:[Nat8]):?TypesBackup.BackupCommonTokenData{
        from_candid(Blob.fromArray(array));        
    };

    public func ConvertAccountHoldersToNat8Array(items:[T.AccountTypes.AccountBalanceInfo]):[Nat8]{
        if (Array.size(items) == 0){
            return [];
        };
        
        return Blob.toArray(to_candid(items)); 
    };

    public func ConvertToAccountHoldersFromNat8Array(array:[Nat8]):?[T.AccountTypes.AccountBalanceInfo]{
          let result:?[T.AccountTypes.AccountBalanceInfo] = from_candid(Blob.fromArray(array));  
          return result;
    };


    //--------------------------------------------------------------------------------


};
