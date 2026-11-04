-- CivilConnect Migration: Synchronize user registration metadata into public profiles
-- Automatically synchronizes full_name, phone, gender, and role (customer vs professional)
-- when a new user registers through the mobile app.

-- 1. Ensure gender column exists on public.profiles
alter table if exists public.profiles
  add column if not exists gender text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_gender_check'
  ) then
    alter table public.profiles
      add constraint profiles_gender_check
      check (gender is null or gender in ('Male', 'Female', 'Other', 'male', 'female', 'other'));
  end if;
end;
$$;

-- 2. Update trigger function to handle gender
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
  v_phone text;
  v_gender text;
  v_pro_code text;
begin
  v_role_text := coalesce(new.raw_user_meta_data ->> 'primary_role', 'customer');
  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', '');
  v_phone := nullif(trim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');
  v_gender := nullif(trim(coalesce(new.raw_user_meta_data ->> 'gender', '')), '');

  -- Safe enum cast
  if v_role_text = 'professional' then
    v_role := 'professional'::public.app_role;
  else
    v_role := 'customer'::public.app_role;
  end if;

  -- Upsert base profile including gender
  insert into public.profiles (
    id,
    email,
    phone,
    full_name,
    gender,
    primary_role,
    account_status
  )
  values (
    new.id,
    new.email,
    v_phone,
    v_full_name,
    v_gender,
    v_role,
    'active'
  )
  on conflict (id) do update set
    email = excluded.email,
    phone = coalesce(excluded.phone, public.profiles.phone),
    full_name = case when excluded.full_name <> '' then excluded.full_name else public.profiles.full_name end,
    gender = coalesce(excluded.gender, public.profiles.gender),
    primary_role = excluded.primary_role,
    updated_at = timezone('utc', now());

  -- Create role-specific subprofile
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

-- Ensure the trigger on auth.users is active
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
