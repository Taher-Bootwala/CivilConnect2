-- ============================================================================
-- CivilConnect - LOGIN & SIGNUP DATABASE SCHEMA & TRIGGERS
-- File: LOGIN_SIGNUP.sql
-- Description: Self-contained SQL script to configure authentication, user
--              registration, gender support, role assignment, and profile sync.
-- ============================================================================

-- 1. Required Extensions
create extension if not exists pgcrypto;
create extension if not exists citext;

-- 2. Custom Enums (Safe Creation)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('customer', 'professional', 'admin', 'support', 'finance', 'operations');
  end if;
  if not exists (select 1 from pg_type where typname = 'account_status') then
    create type public.account_status as enum ('active', 'suspended', 'restricted', 'deleted', 'pending');
  end if;
  if not exists (select 1 from pg_type where typname = 'kyc_status') then
    create type public.kyc_status as enum ('not_started', 'submitted', 'under_review', 'approved', 'rejected', 'expired');
  end if;
end;
$$;

-- 3. Base User Profiles Table (public.profiles)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext,
  phone text,
  full_name text not null default '',
  first_name text,
  last_name text,
  date_of_birth date,
  age integer,
  avatar_path text,
  gender text, -- Added: Stores user gender ('Male', 'Female', 'Other')
  primary_role public.app_role not null default 'customer',
  account_status public.account_status not null default 'active',
  phone_verified_at timestamptz,
  email_verified_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint profiles_full_name_length check (char_length(full_name) <= 160),
  constraint profiles_phone_length check (phone is null or char_length(phone) between 7 and 32),
  constraint profiles_gender_check check (gender is null or gender in ('Male', 'Female', 'Other', 'male', 'female', 'other')),
  constraint profiles_age_check check (age is null or (age >= 0 and age <= 130))
);

-- Ensure the columns exist if public.profiles already existed previously
alter table if exists public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists date_of_birth date,
  add column if not exists age integer,
  add column if not exists gender text;

-- Add check constraint for gender and age if not present
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_gender_check'
  ) then
    alter table public.profiles
      add constraint profiles_gender_check
      check (gender is null or gender in ('Male', 'Female', 'Other', 'male', 'female', 'other'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_age_check'
  ) then
    alter table public.profiles
      add constraint profiles_age_check
      check (age is null or (age >= 0 and age <= 130));
  end if;
end;
$$;

-- Indexes for fast lookup during login and search
create index if not exists profiles_role_status_idx on public.profiles(primary_role, account_status);
create unique index if not exists profiles_phone_unique_idx on public.profiles(phone) where phone is not null and deleted_at is null;
create unique index if not exists profiles_email_unique_idx on public.profiles(email) where email is not null and deleted_at is null;

-- 4. Customer Sub-Profiles Table
create table if not exists public.customer_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  default_address_id uuid,
  marketing_consent boolean not null default false,
  safety_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- 5. Labor / Professional Sub-Profiles Table
create table if not exists public.labor_profiles (
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
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- 6. Trigger Function: Automatically Handle New Registrations
-- Reads metadata (full_name, phone, gender, primary_role) from auth.users
-- and populates public.profiles and the respective role table.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.app_role;
  v_role_text text;
  v_full_name text;
  v_first_name text;
  v_last_name text;
  v_phone text;
  v_gender text;
  v_dob date;
  v_age integer;
  v_pro_code text;
begin
  -- Extract user registration parameters from raw_user_meta_data
  v_role_text := coalesce(new.raw_user_meta_data ->> 'primary_role', 'customer');
  v_first_name := coalesce(new.raw_user_meta_data ->> 'first_name', new.raw_user_meta_data ->> 'given_name', '');
  v_last_name := coalesce(new.raw_user_meta_data ->> 'last_name', new.raw_user_meta_data ->> 'family_name', '');
  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '');

  if v_full_name = '' and (v_first_name <> '' or v_last_name <> '') then
    v_full_name := trim(v_first_name || ' ' || v_last_name);
  end if;

  v_phone := nullif(trim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');
  v_gender := nullif(trim(coalesce(new.raw_user_meta_data ->> 'gender', '')), '');

  begin
    v_dob := (nullif(new.raw_user_meta_data ->> 'date_of_birth', ''))::date;
  exception when others then
    v_dob := null;
  end;

  begin
    v_age := (nullif(new.raw_user_meta_data ->> 'age', ''))::integer;
  exception when others then
    v_age := null;
  end;

  if v_age is null and v_dob is not null then
    v_age := extract(year from age(current_date, v_dob))::integer;
  end if;

  -- Safely parse role enum
  if v_role_text = 'professional' then
    v_role := 'professional'::public.app_role;
  else
    v_role := 'customer'::public.app_role;
  end if;

  -- Insert or update user profile with gender, dob, age, role, phone, and name
  insert into public.profiles (
    id,
    email,
    phone,
    full_name,
    first_name,
    last_name,
    date_of_birth,
    age,
    gender,
    primary_role,
    account_status,
    email_verified_at,
    phone_verified_at
  )
  values (
    new.id,
    new.email,
    v_phone,
    v_full_name,
    v_first_name,
    v_last_name,
    v_dob,
    v_age,
    v_gender,
    v_role,
    'active',
    case when new.email_confirmed_at is not null then new.email_confirmed_at else timezone('utc', now()) end,
    case when v_phone is not null then timezone('utc', now()) else null end
  )
  on conflict (id) do update set
    email = excluded.email,
    phone = coalesce(excluded.phone, public.profiles.phone),
    full_name = case when excluded.full_name <> '' then excluded.full_name else public.profiles.full_name end,
    first_name = coalesce(excluded.first_name, public.profiles.first_name),
    last_name = coalesce(excluded.last_name, public.profiles.last_name),
    date_of_birth = coalesce(excluded.date_of_birth, public.profiles.date_of_birth),
    age = coalesce(excluded.age, public.profiles.age),
    gender = coalesce(excluded.gender, public.profiles.gender),
    primary_role = excluded.primary_role,
    updated_at = timezone('utc', now());

  -- Automatically initialize role subprofile
  if v_role = 'professional' then
    v_pro_code := 'CC-PRO-' || upper(substr(md5(random()::text || new.id::text), 1, 8));
    insert into public.labor_profiles (
      user_id,
      professional_code,
      bio,
      experience_years,
      kyc_status,
      is_online,
      is_available
    )
    values (
      new.id,
      v_pro_code,
      'Service professional ready to take jobs.',
      1.0,
      'not_started',
      true,
      true
    )
    on conflict (user_id) do nothing;
  else
    insert into public.customer_profiles (user_id)
    values (new.id)
    on conflict (user_id) do nothing;
  end if;

  return new;
end;
$$;

-- 7. Trigger on Supabase Auth Table (auth.users)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- 8. Row Level Security (RLS) Policies
alter table public.profiles enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.labor_profiles enable row level security;

-- Profiles: Authenticated users can view their own profile
drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

-- Profiles: Authenticated users can update their own details (name, gender, avatar)
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Profiles: Anyone can view active professional profiles for booking discovery
drop policy if exists "Anyone can view professional profiles" on public.profiles;
create policy "Anyone can view professional profiles"
  on public.profiles for select
  to authenticated, anon
  using (primary_role = 'professional' and account_status = 'active');

-- Customer Profiles: User access policy
drop policy if exists "Customers can manage own profile" on public.customer_profiles;
create policy "Customers can manage own profile"
  on public.customer_profiles for all
  to authenticated
  using (auth.uid() = user_id);

-- Labor Profiles: User access policy
drop policy if exists "Professionals can manage own profile" on public.labor_profiles;
create policy "Professionals can manage own profile"
  on public.labor_profiles for all
  to authenticated
  using (auth.uid() = user_id);

-- Labor Profiles: Public discovery policy
drop policy if exists "Anyone can read available professional profiles" on public.labor_profiles;
create policy "Anyone can read available professional profiles"
  on public.labor_profiles for select
  to authenticated, anon
  using (true);

-- ============================================================================
-- Verification Queries (Run these to test in Supabase SQL Editor):
-- ============================================================================
-- 1. Check all registered profiles with gender:
--    SELECT id, email, phone, full_name, gender, primary_role, account_status, created_at FROM public.profiles;
--
-- 2. Check professional profiles:
--    SELECT p.full_name, p.gender, p.email, lp.professional_code, lp.kyc_status
--    FROM public.profiles p
--    JOIN public.labor_profiles lp ON p.id = lp.user_id;
-- ============================================================================

