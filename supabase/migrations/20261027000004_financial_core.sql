-- CivilConnect Phase 4 / financial core.
-- Pricing calculation, quote submission, provider payment capture, refunds,
-- cash settlement, and professional payout invariants.

alter table public.booking_amount_proposals
  add column if not exists requires_admin_review boolean not null default false;
alter table public.booking_amount_proposals
  add column if not exists estimate_deviation_bps integer not null default 0;
alter table public.cash_settlements
  add column if not exists provider_order_id text;
alter table public.cash_settlements
  add column if not exists provider_payment_id text;
alter table public.cash_settlements
  add column if not exists provider_signature_verified boolean not null default false;
alter table public.refunds add column if not exists idempotency_key text;
create unique index if not exists cash_settlements_provider_order_idx on public.cash_settlements(provider_order_id) where provider_order_id is not null;
create unique index if not exists cash_settlements_provider_payment_idx on public.cash_settlements(provider_payment_id) where provider_payment_id is not null;
create unique index if not exists refunds_idempotency_idx on public.refunds(idempotency_key) where idempotency_key is not null;

-- Ensure ledger helper functions exist before referencing them
create or replace function public.ensure_ledger_account(account_code text, account_name text, account_kind public.ledger_account_type, owner_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare account_uuid uuid;
begin
  insert into public.ledger_accounts(code, name, account_type, owner_user_id)
  values (account_code, account_name, account_kind, owner_id)
  on conflict (code) do nothing;
  select id into account_uuid from public.ledger_accounts where code = account_code;
  return account_uuid;
end;
$$;

create or replace function public.post_ledger_transaction(transaction_uuid uuid)
returns public.ledger_transaction_status
language plpgsql
security definer
set search_path = public
as $$
declare
  tx public.ledger_transactions%rowtype;
  debits bigint;
  credits bigint;
begin
  select * into tx from public.ledger_transactions where id = transaction_uuid for update;
  if not found then raise exception 'ledger transaction not found'; end if;
  if tx.status <> 'draft' then return tx.status; end if;
  select coalesce(sum(amount_paise) filter (where direction = 'debit'), 0),
         coalesce(sum(amount_paise) filter (where direction = 'credit'), 0)
  into debits, credits
  from public.ledger_entries where transaction_id = transaction_uuid;
  if debits = 0 or debits <> credits then
    raise exception 'unbalanced ledger transaction %, debits %, credits %', transaction_uuid, debits, credits;
  end if;
  update public.ledger_transactions set status = 'posted', posted_at = timezone('utc', now()) where id = transaction_uuid;
  return 'posted';
end;
$$;

create or replace function public.submit_booking_quote(
  booking_uuid uuid,
  quote_lines jsonb,
  out_of_range_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  pricing public.service_pricing%rowtype;
  category_id uuid;
  proposal_uuid uuid;
  revision integer;
  labor_amount bigint;
  material_amount bigint;
  visiting_amount bigint;
  add_on_amount bigint;
  subtotal bigint;
  commission_basis bigint;
  commission bigint;
  tax_base bigint;
  tax_amount bigint;
  customer_payable bigint;
  professional_earnings bigint;
  deviation_bps integer := 0;
  requires_review boolean := false;
  line_count integer;
  actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication required'; end if;
  if quote_lines is null or jsonb_typeof(quote_lines) <> 'array' or jsonb_array_length(quote_lines) = 0 or jsonb_array_length(quote_lines) > 50 then
    raise exception 'quote must contain between one and fifty line items';
  end if;

  select * into b from public.bookings where id = booking_uuid and assigned_labor_id = actor for update;
  if not found then raise exception 'booking not found or professional is not assigned'; end if;
  if b.booking_status not in ('in_progress', 'work_done', 'amount_pending_approval', 'disputed') then
    raise exception 'booking is not eligible for a final quote';
  end if;

  select count(*) into line_count
  from jsonb_to_recordset(quote_lines) as item(line_type text, description text, quantity numeric, unit_amount_paise bigint, price_guide_item_id uuid);
  if line_count <> jsonb_array_length(quote_lines) then raise exception 'invalid quote line items'; end if;
  if exists (
    select 1 from jsonb_to_recordset(quote_lines) as item(line_type text, description text, quantity numeric, unit_amount_paise bigint, price_guide_item_id uuid)
    where line_type not in ('labor', 'material', 'visiting', 'add_on')
       or description is null or char_length(description) = 0 or char_length(description) > 500
       or quantity is null or quantity <= 0 or quantity > 100000
       or unit_amount_paise is null or unit_amount_paise < 0 or unit_amount_paise > 1000000000
       or mod(quantity * unit_amount_paise, 1) <> 0
  ) then raise exception 'quote line item validation failed'; end if;
  if exists (
    select 1 from jsonb_to_recordset(quote_lines) as item(line_type text, description text, quantity numeric, unit_amount_paise bigint, price_guide_item_id uuid)
    where item.price_guide_item_id is not null
      and not exists (select 1 from public.service_price_guide_items guide where guide.id = item.price_guide_item_id and guide.service_id = b.service_id and guide.status = 'active')
  ) then raise exception 'price guide item does not belong to the booked service'; end if;

  select
    coalesce(sum(round(item.quantity * item.unit_amount_paise)) filter (where item.line_type = 'labor'), 0)::bigint,
    coalesce(sum(round(item.quantity * item.unit_amount_paise)) filter (where item.line_type = 'material'), 0)::bigint,
    coalesce(sum(round(item.quantity * item.unit_amount_paise)) filter (where item.line_type = 'visiting'), 0)::bigint,
    coalesce(sum(round(item.quantity * item.unit_amount_paise)) filter (where item.line_type = 'add_on'), 0)::bigint
  into labor_amount, material_amount, visiting_amount, add_on_amount
  from jsonb_to_recordset(quote_lines) as item(line_type text, description text, quantity numeric, unit_amount_paise bigint, price_guide_item_id uuid);
  subtotal := labor_amount + material_amount + visiting_amount + add_on_amount;

  select s.category_id into category_id from public.services s where s.id = b.service_id;
  select sp.* into pricing
  from public.service_pricing sp
  where sp.currency = 'INR'
    and sp.effective_from <= timezone('utc', now())
    and (sp.effective_to is null or sp.effective_to > timezone('utc', now()))
    and (
      (sp.scope = 'professional' and sp.professional_id = actor) or
      (sp.scope = 'service' and sp.service_id = b.service_id) or
      (sp.scope = 'category' and sp.category_id = category_id) or
      sp.scope = 'global'
    )
  order by case sp.scope when 'professional' then 1 when 'service' then 2 when 'category' then 3 when 'global' then 4 end,
           sp.effective_from desc, sp.version_number desc
  limit 1;
  if not found then raise exception 'no active pricing configuration exists'; end if;

  commission_basis := labor_amount + add_on_amount;
  if pricing.commission_on_materials then commission_basis := commission_basis + material_amount; end if;
  if pricing.commission_on_visiting_charge then commission_basis := commission_basis + visiting_amount; end if;
  commission := round(commission_basis::numeric * pricing.commission_rate_bps / 10000::numeric)::bigint;
  if pricing.minimum_commission_paise is not null then commission := greatest(commission, pricing.minimum_commission_paise); end if;
  if pricing.maximum_commission_paise is not null then commission := least(commission, pricing.maximum_commission_paise); end if;
  tax_base := labor_amount + visiting_amount + add_on_amount + case when pricing.material_taxable then material_amount else 0 end + pricing.fixed_platform_fee_paise;
  tax_amount := round(tax_base::numeric * pricing.tax_rate_bps / 10000::numeric)::bigint;
  customer_payable := subtotal + pricing.fixed_platform_fee_paise + tax_amount;
  professional_earnings := subtotal - commission;
  if professional_earnings < 0 then raise exception 'commission cannot exceed the service subtotal'; end if;

  if b.estimate_snapshot ->> 'max_paise' is not null and (b.estimate_snapshot ->> 'max_paise')::bigint > 0
     and subtotal > (b.estimate_snapshot ->> 'max_paise')::bigint then
    deviation_bps := round((subtotal - (b.estimate_snapshot ->> 'max_paise')::numeric) * 10000 / (b.estimate_snapshot ->> 'max_paise')::numeric)::integer;
    requires_review := deviation_bps > public.config_int('quote_review_threshold_bps', 2500);
  end if;
  if requires_review and (out_of_range_reason is null or char_length(btrim(out_of_range_reason)) = 0) then
    raise exception 'an explanation is required for a quote above the review threshold';
  end if;

  select coalesce(max(revision_number), 0) + 1 into revision from public.booking_amount_proposals where booking_id = b.id;
  if revision > public.config_int('quote_revision_limit', 2) + 1 then raise exception 'quote revision limit exceeded'; end if;

  insert into public.booking_amount_proposals (
    booking_id, submitted_by, revision_number, status, labor_amount_paise, material_amount_paise,
    visiting_amount_paise, add_on_amount_paise, subtotal_paise, commission_rate_bps, commission_paise,
    fixed_platform_fee_paise, tax_paise, professional_earnings_paise, customer_payable_paise,
    pricing_snapshot, out_of_range_reason, requires_admin_review, estimate_deviation_bps
  ) values (
    b.id, actor, revision, case when b.booking_status = 'disputed' then 'revised'::public.quote_status else 'submitted'::public.quote_status end,
    labor_amount, material_amount, visiting_amount, add_on_amount, subtotal, pricing.commission_rate_bps,
    commission, pricing.fixed_platform_fee_paise, tax_amount, professional_earnings, customer_payable,
    jsonb_build_object(
      'pricing_id', pricing.id, 'pricing_scope', pricing.scope, 'pricing_version', pricing.version_number,
      'commission_rate_bps', pricing.commission_rate_bps, 'minimum_commission_paise', pricing.minimum_commission_paise,
      'maximum_commission_paise', pricing.maximum_commission_paise, 'fixed_platform_fee_paise', pricing.fixed_platform_fee_paise,
      'tax_rate_bps', pricing.tax_rate_bps, 'commission_on_materials', pricing.commission_on_materials,
      'commission_on_visiting_charge', pricing.commission_on_visiting_charge, 'material_taxable', pricing.material_taxable
    ),
    nullif(btrim(out_of_range_reason), ''), requires_review, deviation_bps
  ) returning id into proposal_uuid;

  insert into public.quote_line_items (proposal_id, line_type, description, quantity, unit_amount_paise, total_amount_paise, price_guide_item_id)
  select proposal_uuid, item.line_type::public.quote_line_type, item.description, item.quantity, item.unit_amount_paise,
         round(item.quantity * item.unit_amount_paise)::bigint, item.price_guide_item_id
  from jsonb_to_recordset(quote_lines) as item(line_type text, description text, quantity numeric, unit_amount_paise bigint, price_guide_item_id uuid);

  if b.booking_status = 'in_progress' then
    perform public.transition_booking_status(b.id, 'work_done', 'professional submitted final quote');
    perform public.transition_booking_status(b.id, 'amount_pending_approval', 'quote awaiting customer approval');
  elsif b.booking_status = 'work_done' then
    perform public.transition_booking_status(b.id, 'amount_pending_approval', 'quote awaiting customer approval');
  elsif b.booking_status = 'amount_pending_approval' then
    null;
  end if;
  return jsonb_build_object(
    'proposal_id', proposal_uuid, 'revision_number', revision, 'subtotal_paise', subtotal,
    'commission_paise', commission, 'fixed_platform_fee_paise', pricing.fixed_platform_fee_paise,
    'tax_paise', tax_amount, 'professional_earnings_paise', professional_earnings,
    'customer_payable_paise', customer_payable, 'requires_admin_review', requires_review,
    'estimate_deviation_bps', deviation_bps
  );
end;
$$;

create or replace function public.prepare_online_payment(booking_uuid uuid, request_idempotency_key text)
returns table (payment_id uuid, amount_paise bigint, currency char(3), payment_status public.payment_status)
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  q public.booking_amount_proposals%rowtype;
  existing public.payments%rowtype;
  new_payment uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if request_idempotency_key is null or char_length(request_idempotency_key) < 8 then raise exception 'idempotency key required'; end if;
  select * into existing from public.payments where idempotency_key = request_idempotency_key;
  if found then
    if existing.customer_id <> auth.uid() then raise exception 'idempotency key belongs to another customer'; end if;
    return query select existing.id, existing.amount_paise, existing.currency, existing.status;
    return;
  end if;
  select * into b from public.bookings where id = booking_uuid and customer_id = auth.uid() for update;
  if not found then raise exception 'booking not found or unauthorized'; end if;
  if b.payment_status in ('captured', 'authorized') then raise exception 'booking has already been paid'; end if;
  if b.booking_status not in ('approved', 'payment_pending') then raise exception 'approved quote required before payment'; end if;
  select * into q from public.booking_amount_proposals where booking_id = b.id and status = 'approved' order by revision_number desc limit 1;
  if not found then raise exception 'approved quote required'; end if;
  if b.booking_status = 'approved' then perform public.transition_booking_status(b.id, 'payment_pending', 'online payment initiated'); end if;
  insert into public.payments (booking_id, customer_id, method, status, amount_paise, idempotency_key)
  values (b.id, auth.uid(), 'online', 'pending', q.customer_payable_paise, request_idempotency_key)
  returning id into new_payment;
  return query select new_payment, q.customer_payable_paise, 'INR'::char(3), 'pending'::public.payment_status;
end;
$$;

create or replace function public.mark_online_payment_failed(payment_uuid uuid, failure_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
  update public.payments set status = 'failed', failed_reason = failure_reason, updated_at = timezone('utc', now())
  where id = payment_uuid and status not in ('captured', 'refunded');
end;
$$;

create or replace function public.capture_online_payment(
  payment_uuid uuid,
  provider_payment_uuid text,
  provider_order_uuid text,
  verification_source text default 'razorpay_webhook'
)
returns public.payment_status
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.payments%rowtype;
  o public.payment_provider_orders%rowtype;
  b public.bookings%rowtype;
  q public.booking_amount_proposals%rowtype;
  tx_uuid uuid;
  clearing_account uuid;
  earnings_account uuid;
  commission_account uuid;
  fixed_fee_account uuid;
  tax_account uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
  select * into p from public.payments where id = payment_uuid for update;
  if not found then raise exception 'payment not found'; end if;
  if p.status = 'captured' then return p.status; end if;
  select * into o from public.payment_provider_orders where payment_id = p.id and provider_order_id = provider_order_uuid for update;
  if not found then raise exception 'provider order mismatch'; end if;
  if o.amount_paise <> p.amount_paise then raise exception 'provider amount mismatch'; end if;
  select * into b from public.bookings where id = p.booking_id for update;
  select * into q from public.booking_amount_proposals where booking_id = b.id and status = 'approved' order by revision_number desc limit 1;
  if not found or q.customer_payable_paise <> p.amount_paise then raise exception 'approved quote amount mismatch'; end if;

  clearing_account := public.ensure_ledger_account('asset:razorpay-clearing', 'Razorpay clearing account', 'asset');
  earnings_account := public.ensure_ledger_account('payable:professional:' || b.assigned_labor_id, 'Professional earnings payable', 'payable', b.assigned_labor_id);
  commission_account := public.ensure_ledger_account('revenue:commission', 'Platform commission revenue', 'revenue');
  fixed_fee_account := public.ensure_ledger_account('revenue:fixed-fee', 'Fixed platform fee revenue', 'revenue');
  tax_account := public.ensure_ledger_account('liability:tax', 'Tax liabilities', 'liability');

  insert into public.ledger_transactions(reference, transaction_type, booking_id, payment_id, source_idempotency_key, metadata)
  values ('online-payment:' || provider_payment_uuid, 'online_payment_capture', b.id, p.id, provider_payment_uuid,
          jsonb_build_object('verification_source', verification_source, 'provider_order_id', provider_order_uuid))
  on conflict (reference) do nothing
  returning id into tx_uuid;
  if tx_uuid is null then
    select id into tx_uuid from public.ledger_transactions where reference = 'online-payment:' || provider_payment_uuid;
  else
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo)
    values (tx_uuid, clearing_account, 'debit', q.customer_payable_paise, 'Verified online customer payment');
    if q.professional_earnings_paise > 0 then
      insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, earnings_account, 'credit', q.professional_earnings_paise, 'Professional online earnings');
    end if;
    if q.commission_paise > 0 then
      insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, commission_account, 'credit', q.commission_paise, 'Platform commission');
    end if;
    if q.fixed_platform_fee_paise > 0 then
      insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, fixed_fee_account, 'credit', q.fixed_platform_fee_paise, 'Fixed platform fee');
    end if;
    if q.tax_paise > 0 then
      insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, tax_account, 'credit', q.tax_paise, 'Tax liability');
    end if;
    perform public.post_ledger_transaction(tx_uuid);
  end if;

  update public.payments
  set status = 'captured', provider_payment_id = provider_payment_uuid, captured_at = timezone('utc', now()), updated_at = timezone('utc', now())
  where id = p.id;
  update public.payment_provider_orders set status = 'captured', updated_at = timezone('utc', now()) where id = o.id;
  if b.booking_status = 'payment_pending' then
    perform set_config('civilconnect.allow_transition', 'on', true);
    update public.bookings set payment_status = 'captured', settlement_status = 'not_started', booking_status = 'paid' where id = b.id;
    insert into public.booking_status_history (booking_id, previous_status, next_status, reason, metadata)
    values (b.id, b.booking_status, 'paid', 'verified online payment', jsonb_build_object('provider_payment_id', provider_payment_uuid));
  else
    update public.bookings set payment_status = 'captured' where id = b.id;
  end if;
  return 'captured';
end;
$$;

create or replace function public.request_refund(
  booking_uuid uuid,
  requested_amount_paise bigint,
  refund_reason text,
  request_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  p public.payments%rowtype;
  already uuid;
  captured_amount bigint;
  refunded_amount bigint;
  refund_uuid uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if char_length(coalesce(refund_reason, '')) < 5 then raise exception 'refund reason is required'; end if;
  if request_idempotency_key is null or char_length(request_idempotency_key) < 8 then raise exception 'idempotency key required'; end if;
  select id into already from public.refunds where idempotency_key = request_idempotency_key and requested_by = auth.uid();
  if already is not null then return already; end if;
  select * into b from public.bookings where id = booking_uuid and customer_id = auth.uid() for update;
  if not found then raise exception 'booking not found or unauthorized'; end if;
  select * into p from public.payments where booking_id = b.id and method = 'online' and status = 'captured' order by captured_at desc limit 1 for update;
  if not found then raise exception 'only captured online payments can be refunded through Razorpay'; end if;
  select coalesce(sum(amount_paise) filter (where status in ('pending','requested','processed')), 0)::bigint into refunded_amount from public.refunds where payment_id = p.id;
  captured_amount := p.amount_paise;
  if requested_amount_paise <= 0 or requested_amount_paise > captured_amount - refunded_amount then raise exception 'refund amount exceeds the refundable balance'; end if;
  insert into public.refunds(payment_id, requested_by, amount_paise, status, reason, idempotency_key)
  values (p.id, auth.uid(), requested_amount_paise, 'requested', refund_reason, request_idempotency_key)
  returning id into refund_uuid;
  return refund_uuid;
end;
$$;

create or replace function public.post_processed_refund(refund_uuid uuid, provider_refund_uuid text)
returns public.refund_status
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.refunds%rowtype;
  p public.payments%rowtype;
  q public.booking_amount_proposals%rowtype;
  tx_uuid uuid;
  clearing_account uuid;
  earnings_account uuid;
  commission_account uuid;
  fixed_fee_account uuid;
  tax_account uuid;
  refund_earnings bigint;
  refund_commission bigint;
  refund_fixed bigint;
  refund_tax bigint;
  processed_total bigint;
begin
  if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
  select * into r from public.refunds where id = refund_uuid for update;
  if not found then raise exception 'refund not found'; end if;
  if r.status = 'processed' then return r.status; end if;
  select * into p from public.payments where id = r.payment_id for update;
  select * into q from public.booking_amount_proposals where booking_id = p.booking_id and status = 'approved' order by revision_number desc limit 1;
  if not found then raise exception 'approved quote not found'; end if;
  refund_commission := round(r.amount_paise * q.commission_paise / q.customer_payable_paise::numeric)::bigint;
  refund_fixed := round(r.amount_paise * q.fixed_platform_fee_paise / q.customer_payable_paise::numeric)::bigint;
  refund_tax := round(r.amount_paise * q.tax_paise / q.customer_payable_paise::numeric)::bigint;
  refund_earnings := r.amount_paise - refund_commission - refund_fixed - refund_tax;
  clearing_account := public.ensure_ledger_account('asset:razorpay-clearing', 'Razorpay clearing account', 'asset');
  earnings_account := public.ensure_ledger_account('payable:professional:' || (select assigned_labor_id from public.bookings where id = p.booking_id), 'Professional earnings payable', 'payable', (select assigned_labor_id from public.bookings where id = p.booking_id));
  commission_account := public.ensure_ledger_account('revenue:commission', 'Platform commission revenue', 'revenue');
  fixed_fee_account := public.ensure_ledger_account('revenue:fixed-fee', 'Fixed platform fee revenue', 'revenue');
  tax_account := public.ensure_ledger_account('liability:tax', 'Tax liabilities', 'liability');
  insert into public.ledger_transactions(reference, transaction_type, booking_id, payment_id, source_idempotency_key)
  values ('refund:' || provider_refund_uuid, 'refund', p.booking_id, p.id, provider_refund_uuid)
  on conflict (reference) do nothing returning id into tx_uuid;
  if tx_uuid is null then select id into tx_uuid from public.ledger_transactions where reference = 'refund:' || provider_refund_uuid;
  else
    if refund_earnings > 0 then insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, earnings_account, 'debit', refund_earnings, 'Professional earnings reversal'); end if;
    if refund_commission > 0 then insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, commission_account, 'debit', refund_commission, 'Commission reversal'); end if;
    if refund_fixed > 0 then insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, fixed_fee_account, 'debit', refund_fixed, 'Fixed fee reversal'); end if;
    if refund_tax > 0 then insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, tax_account, 'debit', refund_tax, 'Tax liability reversal'); end if;
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, clearing_account, 'credit', r.amount_paise, 'Verified provider refund');
    perform public.post_ledger_transaction(tx_uuid);
  end if;
  update public.refunds set status = 'processed', provider_refund_id = provider_refund_uuid, processed_at = timezone('utc', now()) where id = r.id;
  select coalesce(sum(amount_paise) filter (where status = 'processed'), 0)::bigint into processed_total from public.refunds where payment_id = p.id;
  update public.payments set status = case when processed_total >= p.amount_paise then 'refunded'::public.payment_status else 'partially_refunded'::public.payment_status end where id = p.id;
  return 'processed';
end;
$$;

create or replace function public.request_cash_settlement(
  settlement_amount_paise bigint,
  request_idempotency_key text
)
returns table (settlement_id uuid, amount_paise bigint, status public.settlement_status)
language plpgsql
security definer
set search_path = public
as $$
declare
  professional_uuid uuid := auth.uid();
  dues bigint;
  existing_id uuid;
  existing_amount bigint;
  existing_status public.settlement_status;
  new_id uuid;
begin
  if professional_uuid is null then raise exception 'authentication required'; end if;
  if request_idempotency_key is null or char_length(request_idempotency_key) < 8 then raise exception 'idempotency key required'; end if;
  if not exists (select 1 from public.labor_profiles where user_id = professional_uuid) then raise exception 'professional profile required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(professional_uuid::text, 0));
  select id, amount_paise, status into existing_id, existing_amount, existing_status from public.cash_settlements where idempotency_key = request_idempotency_key;
  if found then return query select existing_id, existing_amount, existing_status; return; end if;
  select coalesce(sum(outstanding_amount_paise), 0)::bigint into dues from public.platform_receivables where professional_id = professional_uuid;
  if settlement_amount_paise <= 0 or settlement_amount_paise > dues then raise exception 'settlement amount exceeds outstanding platform dues'; end if;
  insert into public.cash_settlements(professional_id, amount_paise, status, idempotency_key)
  values (professional_uuid, settlement_amount_paise, 'pending', request_idempotency_key)
  returning id into new_id;
  return query select new_id, settlement_amount_paise, 'pending'::public.settlement_status;
end;
$$;

drop function if exists public.verify_cash_settlement(uuid, text, text);
create or replace function public.verify_cash_settlement(
  settlement_uuid uuid,
  provider_payment_uuid text,
  provider_order_uuid text,
  provider_amount_paise bigint
)
returns public.settlement_status
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.cash_settlements%rowtype;
  receivable_row record;
  remaining bigint;
  applied bigint;
  bank_account uuid;
  professional_cash_account uuid;
  tx_uuid uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
  select * into s from public.cash_settlements where id = settlement_uuid for update;
  if not found then raise exception 'settlement not found'; end if;
  if s.status = 'settled' then return s.status; end if;
  if provider_amount_paise <> s.amount_paise then raise exception 'settlement provider amount mismatch'; end if;
  if s.provider_order_id is not null and s.provider_order_id <> provider_order_uuid then raise exception 'settlement provider order mismatch'; end if;
  if s.provider_payment_id is not null and s.provider_payment_id <> provider_payment_uuid then raise exception 'settlement provider payment mismatch'; end if;
  remaining := s.amount_paise;
  bank_account := public.ensure_ledger_account('asset:platform-bank', 'Platform bank account', 'asset');
  professional_cash_account := public.ensure_ledger_account('cash:professional:' || s.professional_id, 'Cash collected by professional', 'asset', s.professional_id);
  insert into public.ledger_transactions(reference, transaction_type, source_idempotency_key, metadata)
  values ('cash-settlement:' || provider_payment_uuid, 'cash_settlement', provider_payment_uuid, jsonb_build_object('provider_order_id', provider_order_uuid))
  on conflict (reference) do nothing returning id into tx_uuid;
  if tx_uuid is null then select id into tx_uuid from public.ledger_transactions where reference = 'cash-settlement:' || provider_payment_uuid;
  else
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, bank_account, 'debit', s.amount_paise, 'Verified professional settlement deposit');
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, professional_cash_account, 'credit', s.amount_paise, 'Professional cash obligation settled');
    perform public.post_ledger_transaction(tx_uuid);
  end if;

  for receivable_row in
    select id, outstanding_amount_paise from public.platform_receivables
    where professional_id = s.professional_id and outstanding_amount_paise > 0
    order by created_at, id
    for update
  loop
    exit when remaining = 0;
    applied := least(remaining, receivable_row.outstanding_amount_paise);
    update public.platform_receivables
    set outstanding_amount_paise = outstanding_amount_paise - applied,
        status = case when outstanding_amount_paise - applied = 0 then 'settled'::public.settlement_status else 'partially_settled'::public.settlement_status end,
        updated_at = timezone('utc', now())
    where id = receivable_row.id;
    remaining := remaining - applied;
  end loop;
  if remaining > 0 then raise exception 'settlement exceeds current outstanding receivables'; end if;
  update public.cash_settlements
  set status = 'settled', provider_payment_id = provider_payment_uuid, provider_order_id = provider_order_uuid,
      provider_signature_verified = true, verified_at = timezone('utc', now())
  where id = s.id;
  return 'settled';
end;
$$;

create or replace function public.request_professional_payout(
  payout_amount_paise bigint,
  request_idempotency_key text
)
returns table (payout_id uuid, amount_paise bigint, status public.payout_status, eligible_balance_paise bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  professional_uuid uuid := auth.uid();
  payable_account uuid;
  payable_balance bigint;
  pending_amount bigint;
  eligible_balance bigint;
  existing_id uuid;
  existing_amount bigint;
  existing_status public.payout_status;
  new_id uuid;
begin
  if professional_uuid is null then raise exception 'authentication required'; end if;
  if request_idempotency_key is null or char_length(request_idempotency_key) < 8 then raise exception 'idempotency key required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(professional_uuid::text, 0));
  select id into payable_account from public.ledger_accounts where code = 'payable:professional:' || professional_uuid;
  if payable_account is null then raise exception 'no payable balance exists'; end if;
  select coalesce(sum(case when le.direction = 'credit' then le.amount_paise else -le.amount_paise end), 0)::bigint into payable_balance
  from public.ledger_entries le join public.ledger_transactions lt on lt.id = le.transaction_id
  where le.account_id = payable_account and lt.status in ('posted', 'settled');
  select coalesce(sum(amount_paise), 0)::bigint into pending_amount from public.professional_payouts where professional_id = professional_uuid and status in ('pending', 'processing');
  eligible_balance := greatest(0, payable_balance - pending_amount);
  select id, amount_paise, status into existing_id, existing_amount, existing_status from public.professional_payouts where idempotency_key = request_idempotency_key;
  if found then return query select existing_id, existing_amount, existing_status, eligible_balance; return; end if;
  if payout_amount_paise <= 0 or payout_amount_paise > eligible_balance then raise exception 'payout exceeds eligible payable balance'; end if;
  insert into public.professional_payouts(professional_id, amount_paise, status, idempotency_key)
  values (professional_uuid, payout_amount_paise, 'pending', request_idempotency_key)
  returning id into new_id;
  return query select new_id, payout_amount_paise, 'pending'::public.payout_status, eligible_balance;
end;
$$;

create or replace function public.post_processed_payout(payout_uuid uuid, provider_payout_uuid text)
returns public.payout_status
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.professional_payouts%rowtype;
  payable_account uuid;
  bank_account uuid;
  tx_uuid uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
  select * into p from public.professional_payouts where id = payout_uuid for update;
  if not found then raise exception 'payout not found'; end if;
  if p.status = 'processed' then return p.status; end if;
  payable_account := public.ensure_ledger_account('payable:professional:' || p.professional_id, 'Professional earnings payable', 'payable', p.professional_id);
  bank_account := public.ensure_ledger_account('asset:platform-bank', 'Platform bank account', 'asset');
  insert into public.ledger_transactions(reference, transaction_type, source_idempotency_key, metadata)
  values ('payout:' || provider_payout_uuid, 'professional_payout', provider_payout_uuid, jsonb_build_object('provider_payout_id', provider_payout_uuid))
  on conflict (reference) do nothing returning id into tx_uuid;
  if tx_uuid is null then select id into tx_uuid from public.ledger_transactions where reference = 'payout:' || provider_payout_uuid;
  else
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, payable_account, 'debit', p.amount_paise, 'Professional payout');
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo) values (tx_uuid, bank_account, 'credit', p.amount_paise, 'Platform payout funding');
    perform public.post_ledger_transaction(tx_uuid);
  end if;
  update public.professional_payouts set status = 'processed', provider_payout_id = provider_payout_uuid, processed_at = timezone('utc', now()) where id = p.id;
  return 'processed';
end;
$$;

-- Privilege boundaries for financial functions.
revoke execute on function public.submit_booking_quote(uuid, jsonb, text) from public, anon;
grant execute on function public.submit_booking_quote(uuid, jsonb, text) to authenticated;
revoke execute on function public.prepare_online_payment(uuid, text) from public, anon;
grant execute on function public.prepare_online_payment(uuid, text) to authenticated;
revoke execute on function public.mark_online_payment_failed(uuid, text) from public, anon, authenticated;
grant execute on function public.mark_online_payment_failed(uuid, text) to service_role;
revoke execute on function public.capture_online_payment(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.capture_online_payment(uuid, text, text, text) to service_role;
revoke execute on function public.request_refund(uuid, bigint, text, text) from public, anon;
grant execute on function public.request_refund(uuid, bigint, text, text) to authenticated;
revoke execute on function public.post_processed_refund(uuid, text) from public, anon, authenticated;
grant execute on function public.post_processed_refund(uuid, text) to service_role;
revoke execute on function public.request_cash_settlement(bigint, text) from public, anon;
grant execute on function public.request_cash_settlement(bigint, text) to authenticated;
revoke execute on function public.verify_cash_settlement(uuid, text, text, bigint) from public, anon, authenticated;
grant execute on function public.verify_cash_settlement(uuid, text, text, bigint) to service_role;
revoke execute on function public.request_professional_payout(bigint, text) from public, anon;
grant execute on function public.request_professional_payout(bigint, text) to authenticated;
revoke execute on function public.post_processed_payout(uuid, text) from public, anon, authenticated;
grant execute on function public.post_processed_payout(uuid, text) to service_role;
revoke execute on function public.post_ledger_transaction(uuid) from public, anon, authenticated;
grant execute on function public.post_ledger_transaction(uuid) to service_role;
revoke execute on function public.ensure_ledger_account(text, text, public.ledger_account_type, uuid) from public, anon, authenticated;
grant execute on function public.ensure_ledger_account(text, text, public.ledger_account_type, uuid) to service_role;
