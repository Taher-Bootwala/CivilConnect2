-- ============================================================================
-- Migration: 20261103000000_google_auth_and_dob.sql
-- Description: Adds first_name, last_name, date_of_birth, and age to profiles
--              table and updates auth hook to sync Google OAuth and DOB data.
-- ============================================================================

-- 1. Add new columns to public.profiles if they don't already exist
alter table if exists public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists date_of_birth date,
  add column if not exists age integer;

-- 2. Add validation constraint for age
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_age_check'
  ) then
    alter table public.profiles
      add constraint profiles_age_check
      check (age is null or (age >= 0 and age <= 130));
  end if;
end;
$$;

-- 3. Update the handle_new_auth_user function to sync Google and DOB metadata
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
  
  -- Fallback compose full name from first and last name if needed
  if v_full_name = '' and (v_first_name <> '' or v_last_name <> '') then
    v_full_name := trim(v_first_name || ' ' || v_last_name);
  end if;

  v_phone := nullif(trim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');
  v_gender := nullif(trim(coalesce(new.raw_user_meta_data ->> 'gender', '')), '');
  
  -- Parse Date of Birth and Age
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

  -- If age is not directly provided but DOB is, calculate age
  if v_age is null and v_dob is not null then
    v_age := extract(year from age(current_date, v_dob))::integer;
  end if;

  -- Safely parse role enum
  if v_role_text = 'professional' then
    v_role := 'professional'::public.app_role;
  else
    v_role := 'customer'::public.app_role;
  end if;

  -- Insert or update user profile with google profile, dob, age, gender, role, and phone
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
    v_pro_code := 'PRO-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    insert into public.labor_profiles (
      user_id,
      professional_code,
      kyc_status,
      is_online,
      is_available
    )
    values (
      new.id,
      v_pro_code,
      'not_started',
      false,
      false
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

