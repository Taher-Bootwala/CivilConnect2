-- CivilConnect Phase 2 / migration 2
-- Booking operations, quote workflow, accounting, support, safety, and audit data.

create table public.saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  flat_number text,
  landmark text,
  address_text text not null,
  location geography(point, 4326) not null,
  is_default boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index saved_addresses_user_idx on public.saved_addresses(user_id, is_default);
create index saved_addresses_location_idx on public.saved_addresses using gist(location);
alter table public.customer_profiles add constraint customer_default_address_fk foreign key (default_address_id) references public.saved_addresses(id) on delete set null;

create table public.saved_professionals (
  customer_id uuid not null references public.customer_profiles(user_id) on delete cascade,
  labor_id uuid not null references public.labor_profiles(user_id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (customer_id, labor_id)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_number text not null unique default ('CC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  customer_id uuid not null references public.customer_profiles(user_id),
  service_id uuid not null references public.services(id),
  selected_labor_id uuid references public.labor_profiles(user_id),
  assigned_labor_id uuid references public.labor_profiles(user_id),
  booking_mode public.booking_mode not null,
  booking_status public.booking_status not null default 'requested',
  payment_status public.payment_status not null default 'pending',
  settlement_status public.settlement_status not null default 'not_started',
  scheduled_start timestamptz not null,
  scheduled_end timestamptz not null,
  estimated_duration_minutes integer not null,
  travel_buffer_minutes integer not null default 30,
  problem_description text not null default '',
  cancellation_policy_snapshot jsonb not null default '{}'::jsonb,
  estimate_snapshot jsonb not null default '{}'::jsonb,
  start_otp_hash text,
  start_otp_expires_at timestamptz,
  customer_approved_at timestamptz,
  work_completed_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  appointment_range tstzrange generated always as (tstzrange(scheduled_start, scheduled_end, '[)')) stored,
  constraint booking_professional_mode_check check (
    (booking_mode = 'selected_professional' and selected_labor_id is not null) or
    (booking_mode = 'automatic_match')
  ),
  constraint booking_time_order check (scheduled_end > scheduled_start),
  constraint booking_duration_valid check (estimated_duration_minutes between 15 and 1440),
  constraint booking_buffer_valid check (travel_buffer_minutes between 0 and 720)
);

create index bookings_customer_status_idx on public.bookings(customer_id, booking_status, created_at desc);
create index bookings_assigned_status_idx on public.bookings(assigned_labor_id, booking_status, scheduled_start);
create index bookings_service_status_idx on public.bookings(service_id, booking_status, scheduled_start);
create index bookings_appointment_range_idx on public.bookings using gist(appointment_range);
create index bookings_payment_status_idx on public.bookings(payment_status, settlement_status);
alter table public.bookings add constraint bookings_no_confirmed_overlap
  exclude using gist (assigned_labor_id with =, appointment_range with &&)
  where (assigned_labor_id is not null and booking_status in (
    'requested', 'dispatching', 'accepted', 'on_the_way', 'arrived', 'in_progress',
    'work_done', 'amount_pending_approval', 'approved', 'disputed', 'payment_pending'
  ));

create table public.booking_locations (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  location geography(point, 4326) not null,
  accuracy_m numeric(10, 2),
  address_snapshot text not null default '',
  flat_number text,
  landmark text,
  directions text,
  reverse_geocoder_provider text,
  captured_at timestamptz not null default timezone('utc', now()),
  constraint booking_location_accuracy_valid check (accuracy_m is null or accuracy_m >= 0)
);

create index booking_locations_gist_idx on public.booking_locations using gist(location);

create table public.booking_media (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id),
  media_type text not null check (media_type in ('image', 'voice_note', 'document')),
  stage text not null default 'problem' check (stage in ('problem', 'before', 'after', 'quote', 'dispute', 'other')),
  storage_path text not null unique,
  mime_type text not null,
  byte_size integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint booking_media_size_valid check (byte_size between 1 and 25000000)
);

create index booking_media_booking_idx on public.booking_media(booking_id, stage);

create table public.booking_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  previous_status public.booking_status,
  next_status public.booking_status not null,
  actor_id uuid references public.profiles(id),
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index booking_status_history_booking_idx on public.booking_status_history(booking_id, created_at);

create table public.booking_assignments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  labor_id uuid not null references public.labor_profiles(user_id),
  attempt_number integer not null,
  status public.assignment_status not null default 'pending',
  approximate_distance_m integer,
  rank_score numeric(12, 6),
  dispatched_at timestamptz not null default timezone('utc', now()),
  response_deadline timestamptz,
  responded_at timestamptz,
  rejection_reason text,
  expiry_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (booking_id, labor_id),
  unique (booking_id, attempt_number),
  constraint assignment_attempt_valid check (attempt_number > 0),
  constraint assignment_distance_valid check (approximate_distance_m is null or approximate_distance_m >= 0)
);

create index booking_assignments_labor_status_idx on public.booking_assignments(labor_id, status, response_deadline);
create index booking_assignments_booking_status_idx on public.booking_assignments(booking_id, status);

create table public.labor_live_location (
  labor_id uuid primary key references public.labor_profiles(user_id) on delete cascade,
  location geography(point, 4326) not null,
  accuracy_m numeric(10, 2),
  heading numeric(6, 2),
  speed_mps numeric(8, 2),
  active_booking_id uuid references public.bookings(id) on delete set null,
  is_mock_location boolean not null default false,
  captured_at timestamptz not null default timezone('utc', now()),
  constraint live_location_accuracy_valid check (accuracy_m is null or accuracy_m >= 0),
  constraint live_location_heading_valid check (heading is null or heading between 0 and 360),
  constraint live_location_speed_valid check (speed_mps is null or speed_mps >= 0)
);

create index labor_live_location_gist_idx on public.labor_live_location using gist(location);
create index labor_live_location_booking_idx on public.labor_live_location(active_booking_id);

create table public.work_sessions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  labor_id uuid not null references public.labor_profiles(user_id),
  status public.work_session_status not null default 'pending',
  started_at timestamptz,
  completed_at timestamptz,
  start_latitude numeric(10, 7),
  start_longitude numeric(10, 7),
  start_accuracy_m numeric(10, 2),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint work_session_start_coordinates check ((start_latitude is null and start_longitude is null) or (start_latitude between -90 and 90 and start_longitude between -180 and 180))
);

create unique index one_active_work_session_per_labor_idx on public.work_sessions(labor_id) where status = 'active';

create table public.booking_verifications (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  verification_type public.verification_type not null,
  actor_id uuid references public.profiles(id),
  success boolean not null,
  distance_m numeric(10, 2),
  accuracy_m numeric(10, 2),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index booking_verifications_booking_idx on public.booking_verifications(booking_id, verification_type, created_at desc);

create table public.booking_amount_proposals (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  submitted_by uuid not null references public.labor_profiles(user_id),
  revision_number integer not null,
  status public.quote_status not null default 'submitted',
  labor_amount_paise bigint not null default 0,
  material_amount_paise bigint not null default 0,
  visiting_amount_paise bigint not null default 0,
  add_on_amount_paise bigint not null default 0,
  subtotal_paise bigint not null default 0,
  commission_rate_bps integer not null default 0,
  commission_paise bigint not null default 0,
  fixed_platform_fee_paise bigint not null default 0,
  tax_paise bigint not null default 0,
  professional_earnings_paise bigint not null default 0,
  customer_payable_paise bigint not null default 0,
  pricing_snapshot jsonb not null default '{}'::jsonb,
  out_of_range_reason text,
  submitted_at timestamptz not null default timezone('utc', now()),
  approved_at timestamptz,
  constraint quote_revision_positive check (revision_number > 0),
  constraint quote_components_nonnegative check (
    labor_amount_paise >= 0 and material_amount_paise >= 0 and visiting_amount_paise >= 0 and
    add_on_amount_paise >= 0 and subtotal_paise >= 0 and commission_paise >= 0 and
    fixed_platform_fee_paise >= 0 and tax_paise >= 0 and professional_earnings_paise >= 0 and customer_payable_paise >= 0
  ),
  unique (booking_id, revision_number)
);

create index booking_quotes_status_idx on public.booking_amount_proposals(booking_id, status, revision_number desc);

create table public.quote_line_items (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.booking_amount_proposals(id) on delete cascade,
  line_type public.quote_line_type not null,
  description text not null,
  quantity numeric(12, 3) not null default 1,
  unit_amount_paise bigint not null,
  total_amount_paise bigint not null,
  price_guide_item_id uuid references public.service_price_guide_items(id),
  created_at timestamptz not null default timezone('utc', now()),
  constraint quote_item_quantity_valid check (quantity > 0),
  constraint quote_item_amount_valid check (unit_amount_paise >= 0 and total_amount_paise >= 0)
);

create index quote_line_items_proposal_idx on public.quote_line_items(proposal_id);

create table public.cancellation_penalties (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  assessed_to uuid not null references public.profiles(id),
  actor public.cancellation_actor not null,
  amount_paise bigint not null,
  reason text not null,
  status text not null default 'due' check (status in ('due', 'waived', 'paid', 'cancelled')),
  created_at timestamptz not null default timezone('utc', now()),
  constraint cancellation_amount_valid check (amount_paise >= 0)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  customer_id uuid not null references public.customer_profiles(user_id),
  method public.payment_method not null,
  status public.payment_status not null default 'pending',
  currency char(3) not null default 'INR',
  amount_paise bigint not null,
  provider_payment_id text,
  idempotency_key text not null unique,
  captured_at timestamptz,
  failed_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint payment_amount_valid check (amount_paise > 0)
);

create index payments_booking_status_idx on public.payments(booking_id, status);
create unique index payments_provider_id_idx on public.payments(provider_payment_id) where provider_payment_id is not null;

create table public.payment_provider_orders (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  provider text not null default 'razorpay',
  provider_order_id text not null unique,
  amount_paise bigint not null,
  currency char(3) not null default 'INR',
  public_key_version text,
  status public.payment_status not null default 'order_created',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint provider_order_amount_valid check (amount_paise > 0)
);

create table public.payment_provider_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  payload_hash text not null,
  raw_payload jsonb not null,
  signature_verified boolean not null default false,
  processed_at timestamptz,
  processing_error text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (provider, provider_event_id)
);

create index payment_events_processing_idx on public.payment_provider_events(provider, processed_at);

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id),
  requested_by uuid references public.profiles(id),
  amount_paise bigint not null,
  status public.refund_status not null default 'pending',
  provider_refund_id text unique,
  reason text not null,
  created_at timestamptz not null default timezone('utc', now()),
  processed_at timestamptz,
  constraint refund_amount_valid check (amount_paise > 0)
);

create table public.ledger_accounts (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  account_type public.ledger_account_type not null,
  owner_user_id uuid references public.profiles(id),
  currency char(3) not null default 'INR',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.ledger_transactions (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  status public.ledger_transaction_status not null default 'draft',
  transaction_type text not null,
  currency char(3) not null default 'INR',
  booking_id uuid references public.bookings(id),
  payment_id uuid references public.payments(id),
  source_idempotency_key text unique,
  metadata jsonb not null default '{}'::jsonb,
  posted_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now())
);

create index ledger_transactions_booking_idx on public.ledger_transactions(booking_id, status);
create index ledger_transactions_type_idx on public.ledger_transactions(transaction_type, created_at desc);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.ledger_transactions(id) on delete restrict,
  account_id uuid not null references public.ledger_accounts(id),
  direction public.ledger_direction not null,
  amount_paise bigint not null,
  memo text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint ledger_entry_amount_valid check (amount_paise > 0)
);

create index ledger_entries_transaction_idx on public.ledger_entries(transaction_id);
create index ledger_entries_account_idx on public.ledger_entries(account_id, created_at desc);

create table public.platform_receivables (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.labor_profiles(user_id),
  booking_id uuid references public.bookings(id),
  source_payment_id uuid references public.payments(id),
  original_amount_paise bigint not null,
  outstanding_amount_paise bigint not null,
  status public.settlement_status not null default 'pending',
  due_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint receivable_amounts_valid check (original_amount_paise >= 0 and outstanding_amount_paise between 0 and original_amount_paise)
);

create index platform_receivables_professional_status_idx on public.platform_receivables(professional_id, status, outstanding_amount_paise);

create table public.cash_settlements (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.labor_profiles(user_id),
  amount_paise bigint not null,
  status public.settlement_status not null default 'pending',
  provider text,
  provider_reference text,
  idempotency_key text not null unique,
  requested_at timestamptz not null default timezone('utc', now()),
  verified_at timestamptz,
  verified_by uuid references public.profiles(id),
  failure_reason text,
  constraint cash_settlement_amount_valid check (amount_paise > 0)
);

create index cash_settlements_professional_status_idx on public.cash_settlements(professional_id, status, requested_at desc);

create table public.professional_payouts (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.labor_profiles(user_id),
  amount_paise bigint not null,
  status public.payout_status not null default 'pending',
  provider text not null default 'razorpay',
  provider_payout_id text unique,
  idempotency_key text not null unique,
  requested_at timestamptz not null default timezone('utc', now()),
  processed_at timestamptz,
  failure_reason text,
  constraint payout_amount_valid check (amount_paise > 0)
);

create index professional_payouts_status_idx on public.professional_payouts(professional_id, status, requested_at desc);

create table public.payment_reconciliations (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_reference text not null,
  payment_id uuid references public.payments(id),
  payout_id uuid references public.professional_payouts(id),
  expected_amount_paise bigint,
  actual_amount_paise bigint,
  status public.reconciliation_status not null default 'pending',
  notes text,
  reconciled_by uuid references public.profiles(id),
  reconciled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (provider, provider_reference)
);

create table public.financial_adjustments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id),
  professional_id uuid references public.labor_profiles(user_id),
  customer_id uuid references public.customer_profiles(user_id),
  amount_paise bigint not null,
  direction public.ledger_direction not null,
  reason text not null,
  status public.adjustment_status not null default 'requested',
  requested_by uuid not null references public.profiles(id),
  approved_by uuid references public.profiles(id),
  ledger_transaction_id uuid references public.ledger_transactions(id),
  created_at timestamptz not null default timezone('utc', now()),
  approved_at timestamptz,
  constraint adjustment_amount_valid check (amount_paise > 0)
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  invoice_number text not null unique,
  customer_id uuid not null references public.customer_profiles(user_id),
  total_paise bigint not null,
  currency char(3) not null default 'INR',
  storage_path text,
  issued_at timestamptz not null default timezone('utc', now()),
  constraint invoice_total_valid check (total_paise >= 0)
);

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  reviewer_id uuid not null references public.profiles(id),
  reviewee_id uuid not null references public.profiles(id),
  rating smallint not null,
  comment text,
  tags text[] not null default '{}',
  is_verified boolean not null default false,
  is_visible boolean not null default true,
  moderation_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (booking_id, reviewer_id),
  constraint rating_range_valid check (rating between 1 and 5),
  constraint rating_parties_distinct check (reviewer_id <> reviewee_id)
);

create index ratings_reviewee_idx on public.ratings(reviewee_id, is_visible, created_at desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  booking_id uuid references public.bookings(id) on delete cascade,
  channel public.notification_channel not null default 'in_app',
  status public.notification_status not null default 'queued',
  event_type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  attempts integer not null default 0,
  read_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  constraint notification_attempts_valid check (attempts >= 0)
);

create index notifications_user_inbox_idx on public.notifications(user_id, created_at desc);
create index notifications_pending_idx on public.notifications(status, created_at) where status in ('queued', 'failed');

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null,
  attachment_path text,
  created_at timestamptz not null default timezone('utc', now()),
  read_at timestamptz,
  constraint chat_message_body_valid check (char_length(body) between 1 and 4000)
);

create index chat_messages_thread_idx on public.chat_messages(thread_id, created_at);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  proposal_id uuid references public.booking_amount_proposals(id),
  opened_by uuid not null references public.profiles(id),
  status public.dispute_status not null default 'open',
  reason text not null,
  proposed_amount_paise bigint,
  final_amount_paise bigint,
  resolution_reason text,
  resolved_by uuid references public.profiles(id),
  escalates_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz,
  constraint dispute_amount_valid check (proposed_amount_paise is null or proposed_amount_paise >= 0)
);

create table public.dispute_events (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  actor_id uuid not null references public.profiles(id),
  event_type text not null,
  message text not null,
  proposed_amount_paise bigint,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint dispute_event_amount_valid check (proposed_amount_paise is null or proposed_amount_paise >= 0)
);

create index dispute_events_dispute_idx on public.dispute_events(dispute_id, created_at);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number text not null unique default ('SUP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  created_by uuid not null references public.profiles(id),
  booking_id uuid references public.bookings(id),
  dispute_id uuid references public.disputes(id),
  assigned_to uuid references public.profiles(id),
  status public.ticket_status not null default 'open',
  priority public.ticket_priority not null default 'normal',
  subject text not null,
  description text not null,
  resolution text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz
);

create index support_tickets_queue_idx on public.support_tickets(status, priority, created_at);

create table public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code citext not null unique,
  description text not null default '',
  discount_type text not null check (discount_type in ('fixed', 'percentage')),
  discount_value bigint not null,
  max_discount_paise bigint,
  min_order_paise bigint not null default 0,
  usage_limit integer,
  usage_count integer not null default 0,
  starts_at timestamptz not null,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  constraint promo_discount_valid check (discount_value > 0 and min_order_paise >= 0 and (max_discount_paise is null or max_discount_paise > 0)),
  constraint promo_usage_valid check (usage_count >= 0 and (usage_limit is null or usage_limit >= usage_count))
);

create table public.promotional_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_code_id uuid not null references public.promo_codes(id),
  customer_id uuid not null references public.customer_profiles(user_id),
  booking_id uuid not null unique references public.bookings(id),
  discount_paise bigint not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint redemption_discount_valid check (discount_paise >= 0),
  unique (promo_code_id, customer_id, booking_id)
);

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  phone text not null,
  relationship text,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.sos_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id),
  raised_by uuid not null references public.profiles(id),
  location geography(point, 4326),
  message text,
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  acknowledged_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  request_id text,
  reason text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id, created_at desc);
create index audit_logs_actor_idx on public.audit_logs(actor_id, created_at desc);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  description text not null default '',
  effective_from timestamptz not null default timezone('utc', now()),
  effective_to timestamptz,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint app_config_effective_range check (effective_to is null or effective_to > effective_from)
);

create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  consent_type text not null,
  policy_version text not null,
  granted boolean not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index consents_user_type_idx on public.consents(user_id, consent_type, created_at desc);

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default timezone('utc', now()),
  scheduled_for timestamptz,
  status text not null default 'requested' check (status in ('requested', 'grace_period', 'processing', 'completed', 'cancelled', 'blocked')),
  reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz
);

create table public.policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_type text not null,
  version text not null,
  content jsonb not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  unique (policy_type, version),
  constraint policy_version_range_valid check (effective_to is null or effective_to > effective_from)
);

create index policy_versions_active_idx on public.policy_versions(policy_type, effective_from desc);

create trigger saved_addresses_set_updated_at before update on public.saved_addresses for each row execute function public.set_updated_at();
create trigger bookings_set_updated_at before update on public.bookings for each row execute function public.set_updated_at();
create trigger work_sessions_set_updated_at before update on public.work_sessions for each row execute function public.set_updated_at();
create trigger payments_set_updated_at before update on public.payments for each row execute function public.set_updated_at();
create trigger payment_provider_orders_set_updated_at before update on public.payment_provider_orders for each row execute function public.set_updated_at();
create trigger platform_receivables_set_updated_at before update on public.platform_receivables for each row execute function public.set_updated_at();
create trigger support_tickets_set_updated_at before update on public.support_tickets for each row execute function public.set_updated_at();
