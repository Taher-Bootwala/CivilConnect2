-- Executable smoke checks for a Supabase/PostgreSQL test database.
-- Run after migrations with a database role allowed to call internal ledger functions.

begin;

do $$
declare
  tx_id uuid := gen_random_uuid();
  debit_account uuid := gen_random_uuid();
  credit_account uuid := gen_random_uuid();
  tx_status public.ledger_transaction_status;
begin
  insert into public.ledger_accounts(id, code, name, account_type)
  values
    (debit_account, 'test:debit:' || tx_id, 'Test debit', 'asset'),
    (credit_account, 'test:credit:' || tx_id, 'Test credit', 'liability');
  insert into public.ledger_transactions(id, reference, transaction_type)
  values (tx_id, 'test-balanced:' || tx_id, 'test');
  insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise)
  values
    (tx_id, debit_account, 'debit', 10000),
    (tx_id, credit_account, 'credit', 10000);
  tx_status := public.post_ledger_transaction(tx_id);
  if tx_status <> 'posted' then raise exception 'balanced journal was not posted'; end if;
end;
$$;

do $$
declare
  tx_id uuid := gen_random_uuid();
  account_id uuid := gen_random_uuid();
  rejected boolean := false;
begin
  insert into public.ledger_accounts(id, code, name, account_type)
  values (account_id, 'test:unbalanced:' || tx_id, 'Test unbalanced', 'asset');
  insert into public.ledger_transactions(id, reference, transaction_type)
  values (tx_id, 'test-unbalanced:' || tx_id, 'test');
  insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise)
  values (tx_id, account_id, 'debit', 1);
  begin
    perform public.post_ledger_transaction(tx_id);
  exception when others then
    rejected := true;
  end;
  if not rejected then raise exception 'unbalanced journal was accepted'; end if;
end;
$$;

rollback;
