import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Utils "Utils/Utils";
import T "../../Types/Types.All";
import { ConstantTypes } = "../../Types/Types.All";
import ICRC1 "ICRC1Token";

/// Additional Token implementations
///() ==Additional methods that are not defined in ICRC1 or ICRC2)
module {

    let { SB } = Utils;
    private type AccountType = T.AccountTypes.Account;
    private type TokenData = T.TokenTypes.TokenData;
    private type Balance = T.Balance;
    private type SetTextParameterResult = T.TokenTypes.SetTextParameterResult;
    private type SetBalanceParameterResult = T.TokenTypes.SetBalanceParameterResult;
    private type SetNat8ParameterResult = T.TokenTypes.SetNat8ParameterResult;
    private type ArchiveInterface = T.ArchiveTypes.ArchiveInterface;
    private type Mint = T.TransactionTypes.Mint;
    private type TransferResult = T.TransactionTypes.TransferResult;
    private type BurnArgs = T.TransactionTypes.BurnArgs;
    private type TxIndex = T.TransactionTypes.TxIndex;
    private type Transaction = T.TransactionTypes.Transaction;
    private type GetTransactionsRequest = T.TransactionTypes.GetTransactionsRequest;
    private type GetTransactionsResponse = T.TransactionTypes.GetTransactionsResponse;
    private type QueryArchiveFn = T.TransactionTypes.QueryArchiveFn;
    private type TransactionRange = T.TransactionTypes.TransactionRange;
    private type ArchivedTransaction = T.TransactionTypes.ArchivedTransaction;
    private type TransferArgs = T.TransactionTypes.TransferArgs;

    /// Retrieve the minimum burn amount for the token
    public func min_burn_amount(token : TokenData) : Balance {
        token.min_burn_amount;
    };

    /// Returns the current archive canister
    public func get_archive(token : TokenData) : ArchiveInterface {
        token.archive.canister;
    };

    /// Returns the total number of transactions in the archive
    public func get_archive_stored_txs(token : TokenData) : Nat {
        token.archive.stored_txs;
    };

    /// Returns the total supply of minted tokens
    public func minted_supply(token : TokenData) : Balance {
        token.minted_tokens;
    };

    /// Returns the total supply of burned tokens
    public func burned_supply(token : TokenData) : Balance {
        token.burned_tokens;
    };

    /// Returns the maximum supply of tokens
    public func max_supply(token : TokenData) : Balance {
        token.max_supply;
    };

    /// Helper function to mint tokens with minimum args
    public func mint(
        token : TokenData,
        args : Mint,
        caller : Principal,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
    ) : async* TransferResult {

        if (token.minting_allowed == false) {
            return #Err(#GenericError { error_code = 401; message = "Error: Minting not allowed for this token." });
        };
        if (caller == token.minting_account.owner) {
            let transfer_args : TransferArgs = {
                args with from = token.minting_account;
                from_subaccount = null;
                fee = null;
            };

            await* ICRC1.icrc1_transfer(token, transfer_args, caller, archive_canisterIds);

        } else {
            return #Err(#GenericError { error_code = 401; message = "Unauthorized: Minting not allowed." });
        };
    };

    /// Helper function to burn tokens with minimum args
    public func burn(
        token : TokenData,
        args : BurnArgs,
        caller : Principal,
        archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds,
    ) : async* TransferResult {

        let transfer_args : TransferArgs = {
            args with to = token.minting_account;
            fee = null;
        };

        await* ICRC1.icrc1_transfer(token, transfer_args, caller, archive_canisterIds);
    };

    /// Returns the total number of transactions that have been processed by the given token.
    public func total_transactions(token : TokenData) : Nat {
        let { archive; transactions } = token;
        archive.stored_txs + SB.size(transactions);
    };

    /// Retrieves the transaction specified by the given `tx_index`
    public func get_transaction(token : TokenData, tx_index : TxIndex) : async* ?Transaction {
        let { archive; transactions } = token;

        if (tx_index < archive.stored_txs) {
            await archive.canister.get_transaction(tx_index);
        } else {
            let local_tx_index = (tx_index - archive.stored_txs) : Nat;
            SB.getOpt(transactions, local_tx_index);
        };
    };

    /// Retrieves the transactions specified by the given range
    public func get_transactions(token : TokenData, req : GetTransactionsRequest) : GetTransactionsResponse {
        let { archive; transactions } = token;

        var first_index = 0xFFFF_FFFF_FFFF_FFFF; // returned if no transactions are found

        let req_end = req.start + req.length;
        let tx_end = archive.stored_txs + SB.size(transactions);

        var txs_in_canister : [Transaction] = [];

        if (req.start < tx_end and req_end >= archive.stored_txs) {
            first_index := Nat.max(req.start, archive.stored_txs);
            let tx_start_index = (first_index - archive.stored_txs) : Nat;

            txs_in_canister := SB.slice(transactions, tx_start_index, tx_start_index + req.length);
        };

        let archived_range = if (req.start < archive.stored_txs) {
            {
                start = req.start;
                end = Nat.min(
                    archive.stored_txs,
                    (req.start + req.length) : Nat,
                );
            };
        } else {
            { start = 0; end = 0 };
        };

        let txs_in_archive = (archived_range.end - archived_range.start) : Nat;

        let size = Utils.div_ceil(txs_in_archive, ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST);

        let archived_transactions = Array.tabulate(
            size,
            func(i : Nat) : ArchivedTransaction {
                let offset = i * ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST;
                let start = offset + archived_range.start;
                let length = Nat.min(
                    ConstantTypes.MAX_TRANSACTIONS_PER_REQUEST,
                    archived_range.end - start,
                );

                let callback = token.archive.canister.get_transactions;

                { start; length; callback };
            },
        );

        {
            log_length = txs_in_archive + txs_in_canister.size();
            first_index;
            transactions = txs_in_canister;
            archived_transactions;
        };
    };

    // --------------------------------------------------------------------------------
    // Set or Update values

    /// Set the logo for the token
    public func set_logo(token : TokenData, logo : Text, caller : Principal) : async* SetTextParameterResult {
        if (caller == token.minting_account.owner) {
            token.logo := logo;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting logo only allowed via minting account.";
                }
            );
        };
        #Ok(token.logo);
    };

    /// Set the fee for each transfer
    public func set_fee(token : TokenData, fee : Nat, caller : Principal) : async* SetBalanceParameterResult {
        if (caller == token.minting_account.owner) {
            if (fee >= 10_000 and fee <= 1_000_000_000) {
                token.defaultFee := fee;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: fee must be a value between 10_000 and 1_000_000_000.";
                    }
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting fee only allowed via minting account.";
                }
            );
        };
        #Ok(token.defaultFee);
    };

    /// Set the number of decimals specified for the token
    public func set_decimals(token : TokenData, decimals : Nat8, caller : Principal) : async* SetNat8ParameterResult {
        if (caller == token.minting_account.owner) {
            if (decimals >= 2 and decimals <= 12) {
                token.decimals := decimals;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: decimals must be a value between 2 and 12.";
                    }
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting decimals only allowed via minting account.";
                }
            );
        };
        #Ok(token.decimals);
    };

    /// Set the minimum burn amount
    public func set_min_burn_amount(token : TokenData, min_burn_amount : Nat, caller : Principal) : async* SetBalanceParameterResult {
        if (caller == token.minting_account.owner) {
            if (min_burn_amount >= 10_000 and min_burn_amount <= 1_000_000_000_000) {
                token.min_burn_amount := min_burn_amount;
            } else {
                return #Err(
                    #GenericError {
                        error_code = 400;
                        message = "Bad request: minimum burn amount must be a value between 10_000 and 1_000_000_000_000.";
                    }
                );
            };
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting minimum burn amount only allowed via minting account.";
                }
            );
        };
        #Ok(token.min_burn_amount);
    };

    /// Set the name of the token
    public func set_name(token : TokenData, name : Text, caller : Principal) : async* SetTextParameterResult {
        if (caller == token.minting_account.owner) {
            token.name := name;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting name only allowed via minting account.";
                }
            );
        };
        #Ok(token.name);
    };

    /// Set the symbol of the token
    public func set_symbol(token : TokenData, symbol : Text, caller : Principal) : async* SetTextParameterResult {
        if (caller == token.minting_account.owner) {
            token.symbol := symbol;
        } else {
            return #Err(
                #GenericError {
                    error_code = 401;
                    message = "Unauthorized: Setting symbol only allowed via minting account.";
                }
            );
        };
        #Ok(token.symbol);
    };

    // --------------------------------------------------------------------------------

};
