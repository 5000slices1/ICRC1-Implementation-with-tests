export const idlFactory = ({ IDL }) => {
  const ArchiveInterface = IDL.Rec();
  const Balance = IDL.Nat;
  const Subaccount = IDL.Vec(IDL.Nat8);
  const Account = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(Subaccount),
  });
  const TokenInitArgs = IDL.Record({
    'fee' : Balance,
    'minting_allowed' : IDL.Bool,
    'decimals' : IDL.Nat8,
    'minting_account' : IDL.Opt(Account),
    'logo' : IDL.Text,
    'name' : IDL.Text,
    'initial_balances' : IDL.Vec(IDL.Tuple(Account, Balance)),
    'min_burn_amount' : Balance,
    'max_supply' : Balance,
    'symbol' : IDL.Text,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const Balance__3 = IDL.Nat;
  const CanisterStatsResponse = IDL.Record({
    'principal' : IDL.Text,
    'balance' : Balance__3,
    'name' : IDL.Text,
  });
  const CanisterAutoTopUpDataResponse = IDL.Record({
    'autoCyclesTopUpTimerId' : IDL.Nat,
    'autoCyclesTopUpMinutes' : IDL.Nat,
    'autoCyclesTopUpEnabled' : IDL.Bool,
    'autoCyclesTopUpOccuredNumberOfTimes' : IDL.Nat,
  });
  const Subaccount__1 = IDL.Vec(IDL.Nat8);
  const Balance__2 = IDL.Nat;
  const BurnArgs = IDL.Record({
    'memo' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'from_subaccount' : IDL.Opt(Subaccount__1),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
  });
  const TxIndex = IDL.Nat;
  const Timestamp = IDL.Nat64;
  const TransferError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
    'TemporarilyUnavailable' : IDL.Null,
    'BadBurn' : IDL.Record({ 'min_burn_amount' : Balance__2 }),
    'Duplicate' : IDL.Record({ 'duplicate_of' : TxIndex }),
    'BadFee' : IDL.Record({ 'expected_fee' : Balance__2 }),
    'CreatedInFuture' : IDL.Record({ 'ledger_time' : Timestamp }),
    'TooOld' : IDL.Null,
    'InsufficientFunds' : IDL.Record({ 'balance' : Balance__2 }),
  });
  const TransferResult = IDL.Variant({ 'Ok' : TxIndex, 'Err' : TransferError });
  const Account__1 = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(Subaccount),
  });
  const Burn = IDL.Record({
    'from' : Account__1,
    'memo' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
  });
  const Mint = IDL.Record({
    'to' : Account__1,
    'memo' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
  });
  const Transfer = IDL.Record({
    'to' : Account__1,
    'fee' : Balance__2,
    'from' : Account__1,
    'memo' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
  });
  const Transaction__1 = IDL.Record({
    'burn' : IDL.Opt(Burn),
    'kind' : IDL.Text,
    'mint' : IDL.Opt(Mint),
    'timestamp' : Timestamp,
    'index' : TxIndex,
    'transfer' : IDL.Opt(Transfer),
  });
  const Result_1 = IDL.Variant({ 'ok' : IDL.Null, 'err' : IDL.Text });
  const TxIndex__1 = IDL.Nat;
  const GetTransactionsRequest__1 = IDL.Record({
    'start' : TxIndex,
    'length' : IDL.Nat,
  });
  const Transaction = IDL.Record({
    'burn' : IDL.Opt(Burn),
    'kind' : IDL.Text,
    'mint' : IDL.Opt(Mint),
    'timestamp' : Timestamp,
    'index' : TxIndex,
    'transfer' : IDL.Opt(Transfer),
  });
  const TransactionRange__1 = IDL.Record({
    'transactions' : IDL.Vec(Transaction),
  });
  ArchiveInterface.fill(
    IDL.Service({
      'append_transactions' : IDL.Func(
          [IDL.Vec(Transaction__1)],
          [Result_1],
          [],
        ),
      'cycles_available' : IDL.Func([], [IDL.Nat], ['query']),
      'deposit_cycles' : IDL.Func([], [], []),
      'get_first_tx' : IDL.Func([], [IDL.Nat], ['query']),
      'get_last_tx' : IDL.Func([], [IDL.Nat], ['query']),
      'get_next_archive' : IDL.Func([], [ArchiveInterface], ['query']),
      'get_prev_archive' : IDL.Func([], [ArchiveInterface], ['query']),
      'get_transaction' : IDL.Func(
          [TxIndex__1],
          [IDL.Opt(Transaction__1)],
          ['query'],
        ),
      'get_transactions' : IDL.Func(
          [GetTransactionsRequest__1],
          [TransactionRange__1],
          ['query'],
        ),
      'heap_max' : IDL.Func([], [IDL.Nat], ['query']),
      'heap_total_used' : IDL.Func([], [IDL.Nat], ['query']),
      'init' : IDL.Func([IDL.Nat, IDL.Nat, IDL.Nat], [IDL.Principal], []),
      'max_memory' : IDL.Func([], [IDL.Nat], ['query']),
      'memory_is_full' : IDL.Func([], [IDL.Bool], ['query']),
      'memory_total_used' : IDL.Func([], [IDL.Nat], ['query']),
      'remaining_heap_capacity' : IDL.Func([], [IDL.Nat], ['query']),
      'remaining_memory_capacity' : IDL.Func([], [IDL.Nat], ['query']),
      'set_next_archive' : IDL.Func([ArchiveInterface], [Result_1], []),
      'set_prev_archive' : IDL.Func([ArchiveInterface], [Result_1], []),
      'total_transactions' : IDL.Func([], [IDL.Nat], ['query']),
    })
  );
  const Account__2 = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(Subaccount),
  });
  const AccountBalanceInfo = IDL.Record({
    'balance' : Balance__3,
    'account' : Account__2,
  });
  const GetTransactionsRequest = IDL.Record({
    'start' : TxIndex,
    'length' : IDL.Nat,
  });
  const TransactionRange = IDL.Record({
    'transactions' : IDL.Vec(Transaction),
  });
  const QueryArchiveFn = IDL.Func(
      [GetTransactionsRequest],
      [TransactionRange],
      ['query'],
    );
  const ArchivedTransaction = IDL.Record({
    'callback' : QueryArchiveFn,
    'start' : TxIndex,
    'length' : IDL.Nat,
  });
  const GetTransactionsResponse = IDL.Record({
    'first_index' : TxIndex,
    'log_length' : IDL.Nat,
    'transactions' : IDL.Vec(Transaction),
    'archived_transactions' : IDL.Vec(ArchivedTransaction),
  });
  const Balance__1 = IDL.Nat;
  const Value = IDL.Variant({
    'Int' : IDL.Int,
    'Nat' : IDL.Nat,
    'Blob' : IDL.Vec(IDL.Nat8),
    'Text' : IDL.Text,
  });
  const MetaDatum = IDL.Tuple(IDL.Text, Value);
  const SupportedStandard = IDL.Record({ 'url' : IDL.Text, 'name' : IDL.Text });
  const TransferArgs = IDL.Record({
    'to' : Account__1,
    'fee' : IDL.Opt(Balance__2),
    'memo' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'from_subaccount' : IDL.Opt(Subaccount__1),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
  });
  const AllowanceArgs = IDL.Record({
    'account' : Account__1,
    'spender' : Account__1,
  });
  const Allowance = IDL.Record({
    'allowance' : IDL.Nat,
    'expires_at' : IDL.Opt(IDL.Nat64),
  });
  const Memo = IDL.Vec(IDL.Nat8);
  const ApproveArgs = IDL.Record({
    'fee' : IDL.Opt(Balance__2),
    'memo' : IDL.Opt(Memo),
    'from_subaccount' : IDL.Opt(Subaccount__1),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
    'expected_allowance' : IDL.Opt(IDL.Nat),
    'expires_at' : IDL.Opt(IDL.Nat64),
    'spender' : Account__1,
  });
  const ApproveError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
    'TemporarilyUnavailable' : IDL.Null,
    'Duplicate' : IDL.Record({ 'duplicate_of' : IDL.Nat }),
    'BadFee' : IDL.Record({ 'expected_fee' : IDL.Nat }),
    'AllowanceChanged' : IDL.Record({ 'current_allowance' : IDL.Nat }),
    'CreatedInFuture' : IDL.Record({ 'ledger_time' : IDL.Nat64 }),
    'TooOld' : IDL.Null,
    'Expired' : IDL.Record({ 'ledger_time' : IDL.Nat64 }),
    'InsufficientFunds' : IDL.Record({ 'balance' : IDL.Nat }),
  });
  const ApproveResult = IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : ApproveError });
  const TransferFromArgs = IDL.Record({
    'to' : Account__1,
    'fee' : IDL.Opt(Balance__2),
    'spender_subaccount' : IDL.Opt(Subaccount__1),
    'from' : Account__1,
    'memo' : IDL.Opt(Memo),
    'created_at_time' : IDL.Opt(IDL.Nat64),
    'amount' : Balance__2,
  });
  const TransferFromError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
    'TemporarilyUnavailable' : IDL.Null,
    'InsufficientAllowance' : IDL.Record({ 'allowance' : IDL.Nat }),
    'BadBurn' : IDL.Record({ 'min_burn_amount' : IDL.Nat }),
    'Duplicate' : IDL.Record({ 'duplicate_of' : IDL.Nat }),
    'BadFee' : IDL.Record({ 'expected_fee' : IDL.Nat }),
    'CreatedInFuture' : IDL.Record({ 'ledger_time' : IDL.Nat64 }),
    'TooOld' : IDL.Null,
    'InsufficientFunds' : IDL.Record({ 'balance' : IDL.Nat }),
  });
  const TransferFromResponse = IDL.Variant({
    'Ok' : IDL.Nat,
    'Err' : TransferFromError,
  });
  const SetParameterError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
  });
  const SetNat8ParameterResult = IDL.Variant({
    'Ok' : IDL.Nat8,
    'Err' : SetParameterError,
  });
  const SetBalanceParameterResult = IDL.Variant({
    'Ok' : Balance,
    'Err' : SetParameterError,
  });
  const SetTextParameterResult = IDL.Variant({
    'Ok' : IDL.Text,
    'Err' : SetParameterError,
  });
  const Token = IDL.Service({
    'admin_add_admin_user' : IDL.Func([IDL.Principal], [Result], []),
    'admin_remove_admin_user' : IDL.Func([IDL.Principal], [Result], []),
    'all_canister_stats' : IDL.Func([], [IDL.Vec(CanisterStatsResponse)], []),
    'auto_topup_cycles_disable' : IDL.Func([], [Result], []),
    'auto_topup_cycles_enable' : IDL.Func([IDL.Opt(IDL.Nat)], [Result], []),
    'auto_topup_cycles_status' : IDL.Func(
        [],
        [CanisterAutoTopUpDataResponse],
        [],
      ),
    'burn' : IDL.Func([BurnArgs], [TransferResult], []),
    'cycles_balance' : IDL.Func([], [IDL.Nat], ['query']),
    'deposit_cycles' : IDL.Func([], [], []),
    'feewhitelisting_add_principal' : IDL.Func([IDL.Principal], [Result], []),
    'feewhitelisting_get_list' : IDL.Func(
        [],
        [IDL.Vec(IDL.Principal)],
        ['query'],
      ),
    'feewhitelisting_remove_principal' : IDL.Func(
        [IDL.Principal],
        [Result],
        [],
      ),
    'get_archive' : IDL.Func([], [ArchiveInterface], ['query']),
    'get_archive_stored_txs' : IDL.Func([], [IDL.Nat], ['query']),
    'get_burned_amount' : IDL.Func([], [IDL.Nat], ['query']),
    'get_holders' : IDL.Func(
        [IDL.Opt(IDL.Nat), IDL.Opt(IDL.Nat)],
        [IDL.Vec(AccountBalanceInfo)],
        ['query'],
      ),
    'get_holders_count' : IDL.Func([], [IDL.Nat], ['query']),
    'get_max_supply' : IDL.Func([], [IDL.Nat], ['query']),
    'get_total_tx' : IDL.Func([], [IDL.Nat], ['query']),
    'get_transaction' : IDL.Func([TxIndex], [IDL.Opt(Transaction)], []),
    'get_transactions' : IDL.Func(
        [GetTransactionsRequest],
        [GetTransactionsResponse],
        ['query'],
      ),
    'icrc1_balance_of' : IDL.Func([Account__2], [Balance__1], ['query']),
    'icrc1_decimals' : IDL.Func([], [IDL.Nat8], ['query']),
    'icrc1_fee' : IDL.Func([], [Balance__1], ['query']),
    'icrc1_metadata' : IDL.Func([], [IDL.Vec(MetaDatum)], ['query']),
    'icrc1_minting_account' : IDL.Func([], [IDL.Opt(Account__2)], ['query']),
    'icrc1_name' : IDL.Func([], [IDL.Text], ['query']),
    'icrc1_supported_standards' : IDL.Func(
        [],
        [IDL.Vec(SupportedStandard)],
        ['query'],
      ),
    'icrc1_symbol' : IDL.Func([], [IDL.Text], ['query']),
    'icrc1_total_supply' : IDL.Func([], [Balance__1], ['query']),
    'icrc1_transfer' : IDL.Func([TransferArgs], [TransferResult], []),
    'icrc2_allowance' : IDL.Func([AllowanceArgs], [Allowance], ['query']),
    'icrc2_approve' : IDL.Func([ApproveArgs], [ApproveResult], []),
    'icrc2_transfer_from' : IDL.Func(
        [TransferFromArgs],
        [TransferFromResponse],
        [],
      ),
    'list_admin_users' : IDL.Func([], [IDL.Vec(IDL.Principal)], ['query']),
    'min_burn_amount' : IDL.Func([], [Balance__1], ['query']),
    'mint' : IDL.Func([Mint], [TransferResult], []),
    'real_fee' : IDL.Func(
        [IDL.Principal, IDL.Principal],
        [Balance__1],
        ['query'],
      ),
    'set_decimals' : IDL.Func([IDL.Nat8], [SetNat8ParameterResult], []),
    'set_fee' : IDL.Func([Balance__1], [SetBalanceParameterResult], []),
    'set_logo' : IDL.Func([IDL.Text], [SetTextParameterResult], []),
    'set_min_burn_amount' : IDL.Func(
        [Balance__1],
        [SetBalanceParameterResult],
        [],
      ),
    'set_name' : IDL.Func([IDL.Text], [SetTextParameterResult], []),
    'set_symbol' : IDL.Func([IDL.Text], [SetTextParameterResult], []),
    'token_operation_continue' : IDL.Func([], [Result], []),
    'token_operation_pause' : IDL.Func([IDL.Nat], [Result], []),
    'token_operation_status' : IDL.Func([], [IDL.Text], ['query']),
    'tokens_amount_downscale' : IDL.Func([IDL.Nat8], [Result], []),
    'tokens_amount_upscale' : IDL.Func([IDL.Nat8], [Result], []),
  });
  return Token;
};
export const init = ({ IDL }) => {
  const Balance = IDL.Nat;
  const Subaccount = IDL.Vec(IDL.Nat8);
  const Account = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(Subaccount),
  });
  const TokenInitArgs = IDL.Record({
    'fee' : Balance,
    'minting_allowed' : IDL.Bool,
    'decimals' : IDL.Nat8,
    'minting_account' : IDL.Opt(Account),
    'logo' : IDL.Text,
    'name' : IDL.Text,
    'initial_balances' : IDL.Vec(IDL.Tuple(Account, Balance)),
    'min_burn_amount' : Balance,
    'max_supply' : Balance,
    'symbol' : IDL.Text,
  });
  return [IDL.Opt(TokenInitArgs)];
};
