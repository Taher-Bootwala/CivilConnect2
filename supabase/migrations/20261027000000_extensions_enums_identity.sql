-- CivilConnect Phase 2 / migration 1
-- Extensions, shared enums, identity, onboarding, catalog, and availability.

create extension if not exists postgis;
create extension if not exists btree_gist;
create extension if not exists citext;
create extension if not exists pgcrypto;

create type public.app_role as enum ('customer', 'professional', 'admin', 'support', 'finance', 'operations');
create type public.account_status as enum ('active', 'suspended', 'restricted', 'deleted', 'pending');
create type public.kyc_status as enum ('not_started', 'submitted', 'under_review', 'approved', 'rejected', 'expired');
create type public.service_status as enum ('draft', 'active', 'archived');
create type public.pricing_scope as enum ('global', 'category', 'service', 'professional');
create type public.weekday as enum ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday');
create type public.leave_status as enum ('planned', 'cancelled');
create type public.booking_status as enum (
  'requested', 'dispatching', 'accepted', 'on_the_way', 'arrived', 'in_progress',
  'work_done', 'amount_pending_approval', 'approved', 'disputed', 'payment_pending',
  'paid', 'closed', 'rated', 'rejected', 'expired', 'reassigned', 'cancelled',
  'no_show', 'refund_pending', 'refunded'
);
create type public.booking_mode as enum ('selected_professional', 'automatic_match');
create type public.assignment_status as enum ('pending', 'accepted', 'rejected', 'expired', 'cancelled', 'won');
create type public.work_session_status as enum ('pending', 'active', 'completed', 'cancelled');
create type public.verification_type as enum ('arrival', 'start_otp', 'completion', 'cash_collection');
create type public.quote_status as enum ('draft', 'submitted', 'approved', 'disputed', 'revised', 'rejected', 'resolved');
create type public.quote_line_type as enum ('labor', 'material', 'visiting', 'add_on', 'discount', 'tax');
create type public.payment_method as enum ('online', 'cash');
create type public.payment_status as enum ('pending', 'order_created', 'authorized', 'captured', 'failed', 'partially_refunded', 'refunded', 'disputed');
create type public.settlement_status as enum ('not_started', 'pending', 'partially_settled', 'settled', 'failed', 'reversed');
create type public.ledger_account_type as enum ('asset', 'liability', 'equity', 'revenue', 'expense', 'receivable', 'payable');
create type public.ledger_transaction_status as enum ('draft', 'posted', 'settled', 'reversed', 'failed');
create type public.ledger_direction as enum ('debit', 'credit');
create type public.refund_status as enum ('pending', 'requested', 'processed', 'failed', 'reversed');
create type public.dispute_status as enum ('open', 'awaiting_customer', 'awaiting_professional', 'escalated', 'resolved', 'closed');
create type public.ticket_status as enum ('open', 'in_progress', 'waiting', 'resolved', 'closed');
create type public.ticket_priority as enum ('low', 'normal', 'high', 'urgent');
create type public.notification_channel as enum ('in_app', 'push', 'sms', 'email');
create type public.notification_status as enum ('queued', 'sent', 'delivered', 'read', 'failed');
create type public.payout_status as enum ('pending', 'processing', 'processed', 'failed', 'reversed');
create type public.reconciliation_status as enum ('pending', 'matched', 'mismatched', 'resolved');
create type public.adjustment_status as enum ('requested', 'approved', 'posted', 'rejected');
create type public.cancellation_actor as enum ('customer', 'professional', 'system', 'admin');
create type public.document_type as enum ('identity', 'address', 'tax', 'bank', 'background_check', 'other');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext,
  phone text,
  full_name text not null default '',
  avatar_path text,
  primary_role public.app_role not null default 'customer',
  account_status public.account_status not null default 'active',
  phone_verified_at timestamptz,
  email_verified_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint profiles_full_name_length check (char_length(full_name) <= 160),
  constraint profiles_phone_length check (phone is null or char_length(phone) between 7 and 32)
);

create index profiles_role_status_idx on public.profiles(primary_role, account_status);
create unique index profiles_phone_unique_idx on public.profiles(phone) where phone is not null and deleted_at is null;
create unique index profiles_email_unique_idx on public.profiles(email) where email is not null and deleted_at is null;

create table public.customer_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  default_address_id uuid,
  marketing_consent boolean not null default false,
  safety_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.labor_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  professional_code text not null unique,
  bio text not null default '',
  experience_years numeric(5, 2) not null default 0,
  kyc_status public.kyc_status not null default 'not_started',
  is_online boolean not null default false,
  is_available boolean not null default false,
  is_background_checked boolean not null default false,
  average_rating numeric(4, 3) not null default 0,
  rating_count integer not null default 0,
  completed_job_count integer not null default 0,
  default_travel_radius_m integer not null default 10000,
  bank_account_last4 text,
  upi_handle text,
  payout_profile_provider_id text,
  payout_profile_status text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint labor_experience_nonnegative check (experience_years >= 0),
  constraint labor_rating_valid check (average_rating between 0 and 5 and rating_count >= 0),
  constraint labor_completed_jobs_nonnegative check (completed_job_count >= 0),
  constraint labor_radius_valid check (default_travel_radius_m between 100 and 100000)
);

create index labor_eligibility_idx on public.labor_profiles(kyc_status, is_online, is_available);

create table public.labor_kyc (
  id uuid primary key default gen_random_uuid(),
  labor_id uuid not null references public.labor_profiles(user_id) on delete cascade,
  document_type public.document_type not null,
  document_number_last4 text,
  storage_path text not null,
  status public.kyc_status not null default 'submitted',
  rejection_reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (labor_id, document_type, created_at)
);

create index labor_kyc_labor_status_idx on public.labor_kyc(labor_id, status);

create table public.admin_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role public.app_role not null check (role in ('admin', 'support', 'finance', 'operations')),
  permissions jsonb not null default '{}'::jsonb,
  granted_by uuid references public.profiles(id),
  granted_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz
);

create index admin_roles_active_idx on public.admin_roles(role) where revoked_at is null;

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web', 'unknown')),
  is_active boolean not null default true,
  last_seen_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index device_tokens_user_active_idx on public.device_tokens(user_id, is_active);

create table public.service_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  icon_name text,
  sort_order integer not null default 0,
  status public.service_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index service_categories_status_order_idx on public.service_categories(status, sort_order);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.service_categories(id),
  slug text not null unique,
  name text not null,
  description text not null default '',
  status public.service_status not null default 'active',
  typical_duration_minutes integer not null default 60,
  estimate_min_paise bigint not null default 0,
  estimate_max_paise bigint not null default 0,
  visiting_charge_policy text not null default 'professional_quote',
  search_document tsvector generated always as (
    to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(description, ''))
  ) stored,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint services_duration_positive check (typical_duration_minutes between 15 and 1440),
  constraint services_estimate_valid check (estimate_min_paise >= 0 and estimate_max_paise >= estimate_min_paise)
);

create index services_category_status_idx on public.services(category_id, status);
create index services_search_idx on public.services using gin(search_document);

create table public.service_pricing (
  id uuid primary key default gen_random_uuid(),
  scope public.pricing_scope not null,
  category_id uuid references public.service_categories(id),
  service_id uuid references public.services(id),
  professional_id uuid references public.labor_profiles(user_id),
  version_number integer not null,
  currency char(3) not null default 'INR',
  commission_rate_bps integer not null default 0,
  minimum_commission_paise bigint,
  maximum_commission_paise bigint,
  fixed_platform_fee_paise bigint not null default 0,
  tax_rate_bps integer not null default 0,
  commission_on_materials boolean not null default false,
  commission_on_visiting_charge boolean not null default true,
  material_taxable boolean not null default true,
  effective_from timestamptz not null,
  effective_to timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  constraint service_pricing_scope_target check (
    (scope = 'global' and category_id is null and service_id is null and professional_id is null) or
    (scope = 'category' and category_id is not null and service_id is null and professional_id is null) or
    (scope = 'service' and service_id is not null and professional_id is null) or
    (scope = 'professional' and professional_id is not null)
  ),
  constraint service_pricing_rates_valid check (
    commission_rate_bps between 0 and 10000 and tax_rate_bps between 0 and 10000 and
    fixed_platform_fee_paise >= 0 and
    (minimum_commission_paise is null or minimum_commission_paise >= 0) and
    (maximum_commission_paise is null or maximum_commission_paise >= 0) and
    (maximum_commission_paise is null or minimum_commission_paise is null or maximum_commission_paise >= minimum_commission_paise)
  ),
  constraint service_pricing_effective_range check (effective_to is null or effective_to > effective_from)
);

create index service_pricing_lookup_idx on public.service_pricing(scope, service_id, category_id, professional_id, effective_from desc);

create table public.service_price_guide_items (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(id) on delete cascade,
  name text not null,
  description text not null default '',
  suggested_min_paise bigint not null default 0,
  suggested_max_paise bigint not null default 0,
  is_add_on boolean not null default false,
  status public.service_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guide_item_range_valid check (suggested_min_paise >= 0 and suggested_max_paise >= suggested_min_paise)
);

create index service_price_guide_service_idx on public.service_price_guide_items(service_id, status);

create table public.labor_services (
  labor_id uuid not null references public.labor_profiles(user_id) on delete cascade,
  service_id uuid not null references public.services(id) on delete cascade,
  years_experience numeric(5, 2) not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (labor_id, service_id),
  constraint labor_service_experience_nonnegative check (years_experience >= 0)
);

create index labor_services_service_idx on public.labor_services(service_id, labor_id);

create table public.labor_availability (
  id uuid primary key default gen_random_uuid(),
  labor_id uuid not null references public.labor_profiles(user_id) on delete cascade,
  day_of_week public.weekday not null,
  start_local time not null,
  end_local time not null,
  timezone_name text not null default 'Asia/Kolkata',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint availability_time_order check (end_local > start_local)
);

create index labor_availability_lookup_idx on public.labor_availability(labor_id, day_of_week, is_active);

create table public.labor_leaves (
  id uuid primary key default gen_random_uuid(),
  labor_id uuid not null references public.labor_profiles(user_id) on delete cascade,
  leave_range tstzrange not null,
  reason text,
  status public.leave_status not null default 'planned',
  created_at timestamptz not null default timezone('utc', now()),
  constraint labor_leave_range_valid check (not isempty(leave_range))
);

create index labor_leaves_range_idx on public.labor_leaves using gist(labor_id, leave_range);

create table public.service_areas (
  id uuid primary key default gen_random_uuid(),
  labor_id uuid not null references public.labor_profiles(user_id) on delete cascade,
  center geography(point, 4326) not null,
  radius_m integer not null,
  label text,
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint service_area_radius_valid check (radius_m between 100 and 100000)
);

create index service_areas_center_gist_idx on public.service_areas using gist(center);
create index service_areas_labor_idx on public.service_areas(labor_id, is_primary);

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger customer_profiles_set_updated_at before update on public.customer_profiles for each row execute function public.set_updated_at();
create trigger labor_profiles_set_updated_at before update on public.labor_profiles for each row execute function public.set_updated_at();
create trigger labor_kyc_set_updated_at before update on public.labor_kyc for each row execute function public.set_updated_at();
create trigger device_tokens_set_updated_at before update on public.device_tokens for each row execute function public.set_updated_at();
create trigger service_categories_set_updated_at before update on public.service_categories for each row execute function public.set_updated_at();
create trigger services_set_updated_at before update on public.services for each row execute function public.set_updated_at();
create trigger service_price_guide_set_updated_at before update on public.service_price_guide_items for each row execute function public.set_updated_at();
create trigger labor_availability_set_updated_at before update on public.labor_availability for each row execute function public.set_updated_at();
create trigger service_areas_set_updated_at before update on public.service_areas for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  insert into public.customer_profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
