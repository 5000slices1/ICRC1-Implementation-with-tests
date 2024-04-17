import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Account {
  'owner' : Principal,
  'subaccount' : [] | [Subaccount],
}
export interface AccountBalanceInfo {
  'balance' : Balance__3,
  'account' : Account__2,
}
export interface Account__1 {
  'owner' : Principal,
  'subaccount' : [] | [Subaccount],
}
export interface Account__2 {
  'owner' : Principal,
  'subaccount' : [] | [Subaccount],
}
export interface Allowance {
  'allowance' : bigint,
  'expires_at' : [] | [bigint],
}
export interface AllowanceArgs {
  'account' : Account__1,
  'spender' : Account__1,
}
export interface ApproveArgs {
  'fee' : [] | [Balance__2],
  'memo' : [] | [Memo],
  'from_subaccount' : [] | [Subaccount__1],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
  'expected_allowance' : [] | [bigint],
  'expires_at' : [] | [bigint],
  'spender' : Account__1,
}
export type ApproveError = {
    'GenericError' : { 'message' : string, 'error_code' : bigint }
  } |
  { 'TemporarilyUnavailable' : null } |
  { 'Duplicate' : { 'duplicate_of' : bigint } } |
  { 'BadFee' : { 'expected_fee' : bigint } } |
  { 'AllowanceChanged' : { 'current_allowance' : bigint } } |
  { 'CreatedInFuture' : { 'ledger_time' : bigint } } |
  { 'TooOld' : null } |
  { 'Expired' : { 'ledger_time' : bigint } } |
  { 'InsufficientFunds' : { 'balance' : bigint } };
export type ApproveResult = { 'Ok' : bigint } |
  { 'Err' : ApproveError };
export interface ArchiveInterface {
  'append_transactions' : ActorMethod<[Array<Transaction__1>], Result_1>,
  'cycles_available' : ActorMethod<[], bigint>,
  'deposit_cycles' : ActorMethod<[], undefined>,
  'get_first_tx' : ActorMethod<[], bigint>,
  'get_last_tx' : ActorMethod<[], bigint>,
  'get_next_archive' : ActorMethod<[], Principal>,
  'get_prev_archive' : ActorMethod<[], Principal>,
  'get_transaction' : ActorMethod<[TxIndex__1], [] | [Transaction__1]>,
  'get_transactions' : ActorMethod<
    [GetTransactionsRequest__1],
    TransactionRange__1
  >,
  'heap_max' : ActorMethod<[], bigint>,
  'heap_total_used' : ActorMethod<[], bigint>,
  'init' : ActorMethod<[bigint, bigint, bigint], Principal>,
  'max_memory' : ActorMethod<[], bigint>,
  'memory_is_full' : ActorMethod<[], boolean>,
  'memory_total_used' : ActorMethod<[], bigint>,
  'remaining_heap_capacity' : ActorMethod<[], bigint>,
  'remaining_memory_capacity' : ActorMethod<[], bigint>,
  'set_next_archive' : ActorMethod<[Principal], Result_1>,
  'set_prev_archive' : ActorMethod<[Principal], Result_1>,
  'total_transactions' : ActorMethod<[], bigint>,
}
export interface ArchivedTransaction {
  'callback' : QueryArchiveFn,
  'start' : TxIndex,
  'length' : bigint,
}
export type Balance = bigint;
export type Balance__1 = bigint;
export type Balance__2 = bigint;
export type Balance__3 = bigint;
export interface Burn {
  'from' : Account__1,
  'memo' : [] | [Uint8Array | number[]],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
}
export interface BurnArgs {
  'memo' : [] | [Uint8Array | number[]],
  'from_subaccount' : [] | [Subaccount__1],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
}
export interface CanisterAutoTopUpDataResponse {
  'autoCyclesTopUpTimerId' : bigint,
  'autoCyclesTopUpMinutes' : bigint,
  'autoCyclesTopUpEnabled' : boolean,
  'autoCyclesTopUpOccuredNumberOfTimes' : bigint,
}
export interface CanisterStatsResponse {
  'principal' : string,
  'balance' : Balance__3,
  'name' : string,
}
export interface GetTransactionsRequest { 'start' : TxIndex, 'length' : bigint }
export interface GetTransactionsRequest__1 {
  'start' : TxIndex,
  'length' : bigint,
}
export interface GetTransactionsResponse {
  'first_index' : TxIndex,
  'log_length' : bigint,
  'transactions' : Array<Transaction>,
  'archived_transactions' : Array<ArchivedTransaction>,
}
export type Memo = Uint8Array | number[];
export type MetaDatum = [string, Value];
export interface Mint {
  'to' : Account__1,
  'memo' : [] | [Uint8Array | number[]],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
}
export type QueryArchiveFn = ActorMethod<
  [GetTransactionsRequest],
  TransactionRange
>;
export type Result = { 'ok' : string } |
  { 'err' : string };
export type Result_1 = { 'ok' : null } |
  { 'err' : string };
export type SetBalanceParameterResult = { 'Ok' : Balance } |
  { 'Err' : SetParameterError };
export type SetNat8ParameterResult = { 'Ok' : number } |
  { 'Err' : SetParameterError };
export type SetParameterError = {
    'GenericError' : { 'message' : string, 'error_code' : bigint }
  };
export type SetTextParameterResult = { 'Ok' : string } |
  { 'Err' : SetParameterError };
export type Subaccount = Uint8Array | number[];
export type Subaccount__1 = Uint8Array | number[];
export interface SupportedStandard { 'url' : string, 'name' : string }
export type Timestamp = bigint;
export interface Token {
  'admin_add_admin_user' : ActorMethod<[Principal], Result>,
  'admin_remove_admin_user' : ActorMethod<[Principal], Result>,
  'all_canister_stats' : ActorMethod<[], Array<CanisterStatsResponse>>,
  'auto_topup_cycles_disable' : ActorMethod<[], Result>,
  'auto_topup_cycles_enable' : ActorMethod<[[] | [bigint]], Result>,
  'auto_topup_cycles_status' : ActorMethod<[], CanisterAutoTopUpDataResponse>,
  'burn' : ActorMethod<[BurnArgs], TransferResult>,
  'cycles_balance' : ActorMethod<[], bigint>,
  'deposit_cycles' : ActorMethod<[], undefined>,
  'feewhitelisting_add_principal' : ActorMethod<[Principal], Result>,
  'feewhitelisting_get_list' : ActorMethod<[], Array<Principal>>,
  'feewhitelisting_remove_principal' : ActorMethod<[Principal], Result>,
  'get_archive' : ActorMethod<[], Principal>,
  'get_archive_stored_txs' : ActorMethod<[], bigint>,
  'get_burned_amount' : ActorMethod<[], bigint>,
  'get_holders' : ActorMethod<
    [[] | [bigint], [] | [bigint]],
    Array<AccountBalanceInfo>
  >,
  'get_holders_count' : ActorMethod<[], bigint>,
  'get_max_supply' : ActorMethod<[], bigint>,
  'get_total_tx' : ActorMethod<[], bigint>,
  'get_transaction' : ActorMethod<[TxIndex], [] | [Transaction]>,
  'get_transactions' : ActorMethod<
    [GetTransactionsRequest],
    GetTransactionsResponse
  >,
  'icrc1_balance_of' : ActorMethod<[Account__2], Balance__1>,
  'icrc1_decimals' : ActorMethod<[], number>,
  'icrc1_fee' : ActorMethod<[], Balance__1>,
  'icrc1_metadata' : ActorMethod<[], Array<MetaDatum>>,
  'icrc1_minting_account' : ActorMethod<[], [] | [Account__2]>,
  'icrc1_name' : ActorMethod<[], string>,
  'icrc1_supported_standards' : ActorMethod<[], Array<SupportedStandard>>,
  'icrc1_symbol' : ActorMethod<[], string>,
  'icrc1_total_supply' : ActorMethod<[], Balance__1>,
  'icrc1_transfer' : ActorMethod<[TransferArgs], TransferResult>,
  'icrc2_allowance' : ActorMethod<[AllowanceArgs], Allowance>,
  'icrc2_approve' : ActorMethod<[ApproveArgs], ApproveResult>,
  'icrc2_transfer_from' : ActorMethod<[TransferFromArgs], TransferFromResponse>,
  'list_admin_users' : ActorMethod<[], Array<Principal>>,
  'min_burn_amount' : ActorMethod<[], Balance__1>,
  'mint' : ActorMethod<[Mint], TransferResult>,
  'parallel_test_internal' : ActorMethod<[], undefined>,
  'parallel_test_run' : ActorMethod<[], undefined>,
  'parallel_test_show_counter' : ActorMethod<[], bigint>,
  'real_fee' : ActorMethod<[Principal, Principal], Balance__1>,
  'set_decimals' : ActorMethod<[number], SetNat8ParameterResult>,
  'set_fee' : ActorMethod<[Balance__1], SetBalanceParameterResult>,
  'set_logo' : ActorMethod<[string], SetTextParameterResult>,
  'set_min_burn_amount' : ActorMethod<[Balance__1], SetBalanceParameterResult>,
  'set_name' : ActorMethod<[string], SetTextParameterResult>,
  'set_symbol' : ActorMethod<[string], SetTextParameterResult>,
  'token_operation_continue' : ActorMethod<[], Result>,
  'token_operation_pause' : ActorMethod<[bigint], Result>,
  'token_operation_status' : ActorMethod<[], string>,
  'tokens_amount_downscale' : ActorMethod<[number], Result>,
  'tokens_amount_upscale' : ActorMethod<[number], Result>,
}
export interface TokenInitArgs {
  'fee' : Balance,
  'minting_allowed' : boolean,
  'decimals' : number,
  'minting_account' : [] | [Account],
  'logo' : string,
  'name' : string,
  'initial_balances' : Array<[Account, Balance]>,
  'min_burn_amount' : Balance,
  'max_supply' : Balance,
  'symbol' : string,
}
export interface Transaction {
  'burn' : [] | [Burn],
  'kind' : string,
  'mint' : [] | [Mint],
  'timestamp' : Timestamp,
  'index' : TxIndex,
  'transfer' : [] | [Transfer],
}
export interface TransactionRange { 'transactions' : Array<Transaction> }
export interface TransactionRange__1 { 'transactions' : Array<Transaction> }
export interface Transaction__1 {
  'burn' : [] | [Burn],
  'kind' : string,
  'mint' : [] | [Mint],
  'timestamp' : Timestamp,
  'index' : TxIndex,
  'transfer' : [] | [Transfer],
}
export interface Transfer {
  'to' : Account__1,
  'fee' : Balance__2,
  'from' : Account__1,
  'memo' : [] | [Uint8Array | number[]],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
}
export interface TransferArgs {
  'to' : Account__1,
  'fee' : [] | [Balance__2],
  'memo' : [] | [Uint8Array | number[]],
  'from_subaccount' : [] | [Subaccount__1],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
}
export type TransferError = {
    'GenericError' : { 'message' : string, 'error_code' : bigint }
  } |
  { 'TemporarilyUnavailable' : null } |
  { 'BadBurn' : { 'min_burn_amount' : Balance__2 } } |
  { 'Duplicate' : { 'duplicate_of' : TxIndex } } |
  { 'BadFee' : { 'expected_fee' : Balance__2 } } |
  { 'CreatedInFuture' : { 'ledger_time' : Timestamp } } |
  { 'TooOld' : null } |
  { 'InsufficientFunds' : { 'balance' : Balance__2 } };
export interface TransferFromArgs {
  'to' : Account__1,
  'fee' : [] | [Balance__2],
  'spender_subaccount' : [] | [Subaccount__1],
  'from' : Account__1,
  'memo' : [] | [Memo],
  'created_at_time' : [] | [bigint],
  'amount' : Balance__2,
}
export type TransferFromError = {
    'GenericError' : { 'message' : string, 'error_code' : bigint }
  } |
  { 'TemporarilyUnavailable' : null } |
  { 'InsufficientAllowance' : { 'allowance' : bigint } } |
  { 'BadBurn' : { 'min_burn_amount' : bigint } } |
  { 'Duplicate' : { 'duplicate_of' : bigint } } |
  { 'BadFee' : { 'expected_fee' : bigint } } |
  { 'CreatedInFuture' : { 'ledger_time' : bigint } } |
  { 'TooOld' : null } |
  { 'InsufficientFunds' : { 'balance' : bigint } };
export type TransferFromResponse = { 'Ok' : bigint } |
  { 'Err' : TransferFromError };
export type TransferResult = { 'Ok' : TxIndex } |
  { 'Err' : TransferError };
export type TxIndex = bigint;
export type TxIndex__1 = bigint;
export type Value = { 'Int' : bigint } |
  { 'Nat' : bigint } |
  { 'Blob' : Uint8Array | number[] } |
  { 'Text' : string };
export interface _SERVICE extends Token {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
