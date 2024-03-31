
import T "../../Types/Types.All";
import Model "../../Types/Types.Model";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Itertools "mo:itertools/Iter";
import Constants "../../Types/Types.Constants";

module {

  public func ConvertTokenInitArgs(
        init_arguments : ?T.TokenTypes.TokenInitArgs, 
        model:Model.Model,
        canisterOwner:Principal
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
            if (amount < Constants.TOKEN_INITIAL_CYCLES_REQUIRED) {
                let missingBalance : Nat = Constants.TOKEN_INITIAL_CYCLES_REQUIRED - amount;
                let infoText : Text = "\r\nERROR! At least " #debug_show (Constants.TOKEN_INITIAL_DEPLOYMENT_CYCLES_REQUIRED)
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



};