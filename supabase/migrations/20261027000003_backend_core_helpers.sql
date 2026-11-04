-- CivilConnect Phase 3 support migration.
-- Transactional helpers used by the booking and professional Edge Functions.

alter table public.labor_kyc add column if not exists mime_type text;
alter table public.labor_kyc add column if not exists byte_size integer;
alter table public.labor_kyc drop constraint if exists labor_kyc_file_size_valid;
alter table public.labor_kyc add constraint labor_kyc_file_size_valid check (byte_size is null or byte_size between 1 and 10000000);

-- Ensure authorization helper is available
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_roles
    where user_id = auth.uid() and revoked_at is null
  );
$$;

grant execute on function public.is_staff() to authenticated, service_role;

create or replace function public.respond_to_booking_assignment(
  booking_uuid uuid,
  accept_request boolean,
  rejection_reason text default null
)
returns public.booking_status
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  a public.booking_assignments%rowtype;
  actor uuid := auth.uid();
  next_status public.booking_status;
  pending_count integer;
begin
  if actor is null then raise exception 'authentication required'; end if;
  select * into b from public.bookings where id = booking_uuid for update;
  if not found then raise exception 'booking not found'; end if;
  select * into a from public.booking_assignments
  where booking_id = booking_uuid and labor_id = actor
  order by attempt_number desc limit 1 for update;
  if not found or a.status <> 'pending' then raise exception 'assignment is no longer pending'; end if;

  if a.response_deadline is not null and a.response_deadline <= timezone('utc', now()) then
    update public.booking_assignments
    set status = 'expired', responded_at = timezone('utc', now()), expiry_reason = 'response deadline elapsed'
    where id = a.id;
    raise exception 'assignment response window expired';
  end if;
  if b.booking_status not in ('requested', 'dispatching') then raise exception 'booking is not awaiting assignment'; end if;

  if accept_request then
    if b.assigned_labor_id is not null and b.assigned_labor_id <> actor then
      raise exception 'booking has already been won by another professional';
    end if;
    update public.bookings set assigned_labor_id = actor where id = booking_uuid;
    update public.booking_assignments
    set status = 'won', responded_at = timezone('utc', now())
    where id = a.id;
    update public.booking_assignments
    set status = 'cancelled', responded_at = timezone('utc', now()), expiry_reason = 'another professional accepted'
    where booking_id = booking_uuid and id <> a.id and status = 'pending';
    perform public.transition_booking_status(booking_uuid, 'accepted', 'professional accepted assignment');
    return 'accepted';
  end if;

  update public.booking_assignments
  set status = 'rejected', responded_at = timezone('utc', now()), rejection_reason = rejection_reason
  where id = a.id;
  select count(*) into pending_count from public.booking_assignments where booking_id = booking_uuid and status = 'pending';

  if b.booking_mode = 'selected_professional' then
    perform public.transition_booking_status(booking_uuid, 'rejected', coalesce(rejection_reason, 'professional rejected assignment'));
    return 'rejected';
  end if;
  if pending_count = 0 then
    next_status := 'reassigned';
    perform set_config('civilconnect.allow_transition', 'on', true);
    update public.bookings set booking_status = next_status where id = booking_uuid;
    insert into public.booking_status_history (booking_id, previous_status, next_status, actor_id, reason, metadata)
    values (booking_uuid, b.booking_status, next_status, actor, 'automatic dispatch requires reassignment', '{}'::jsonb);
  else
    next_status := b.booking_status;
  end if;
  return next_status;
end;
$$;

create or replace function public.issue_start_otp(booking_uuid uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  otp text;
  b public.bookings%rowtype;
begin
  select * into b from public.bookings where id = booking_uuid and customer_id = auth.uid() for update;
  if not found then raise exception 'booking not found or unauthorized'; end if;
  if b.booking_status <> 'arrived' then raise exception 'professional must be verified as arrived first'; end if;
  otp := lpad((
    (get_byte(gen_random_bytes(1), 0) * 65536 +
     get_byte(gen_random_bytes(1), 0) * 256 +
     get_byte(gen_random_bytes(1), 0)) % 1000000
  )::text, 6, '0');
  update public.bookings
  set start_otp_hash = crypt(otp, gen_salt('bf')), start_otp_expires_at = timezone('utc', now()) + interval '10 minutes'
  where id = booking_uuid;
  insert into public.booking_verifications (booking_id, verification_type, actor_id, success, metadata)
  values (booking_uuid, 'start_otp', auth.uid(), true, jsonb_build_object('issued', true));
  return otp;
end;
$$;

create or replace function public.publish_live_location(
  booking_uuid uuid,
  latitude numeric,
  longitude numeric,
  accuracy numeric default null,
  heading_degrees numeric default null,
  speed numeric default null,
  mock_location boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
begin
  if latitude not between -90 and 90 or longitude not between -180 and 180 then raise exception 'invalid coordinates'; end if;
  select * into b from public.bookings where id = booking_uuid and assigned_labor_id = auth.uid() for update;
  if not found then raise exception 'not authorized for booking'; end if;
  if b.booking_status not in ('on_the_way', 'arrived', 'in_progress', 'work_done') then raise exception 'live location is not enabled for this booking state'; end if;
  insert into public.labor_live_location (labor_id, location, accuracy_m, heading, speed_mps, active_booking_id, is_mock_location, captured_at)
  values (auth.uid(), st_setsrid(st_makepoint(longitude, latitude), 4326)::geography, accuracy, heading_degrees, speed, booking_uuid, mock_location, timezone('utc', now()))
  on conflict (labor_id) do update set
    location = excluded.location,
    accuracy_m = excluded.accuracy_m,
    heading = excluded.heading,
    speed_mps = excluded.speed_mps,
    active_booking_id = excluded.active_booking_id,
    is_mock_location = excluded.is_mock_location,
    captured_at = excluded.captured_at;
end;
$$;

create or replace function public.verify_arrival(
  booking_uuid uuid,
  latitude numeric,
  longitude numeric,
  accuracy numeric default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  customer_location geography;
  professional_distance numeric;
  radius_m integer;
  accuracy_ok boolean;
  distance_ok boolean;
begin
  select * into b from public.bookings where id = booking_uuid and assigned_labor_id = auth.uid() for update;
  if not found then raise exception 'not authorized for booking'; end if;
  if b.booking_status <> 'on_the_way' then raise exception 'booking is not on the way'; end if;
  if latitude not between -90 and 90 or longitude not between -180 and 180 then raise exception 'invalid coordinates'; end if;

  select location into customer_location from public.booking_locations where booking_id = booking_uuid;
  radius_m := public.config_int('arrival_geofence_radius_m', 150);
  accuracy_ok := accuracy is null or accuracy <= public.config_int('maximum_arrival_accuracy_m', 100);
  professional_distance := st_distance(st_setsrid(st_makepoint(longitude, latitude), 4326)::geography, customer_location);
  distance_ok := professional_distance <= radius_m;

  insert into public.booking_verifications (booking_id, verification_type, actor_id, success, distance_m, accuracy_m, metadata)
  values (booking_uuid, 'arrival', auth.uid(), distance_ok and accuracy_ok, professional_distance, accuracy,
          jsonb_build_object('radius_m', radius_m, 'server_time', timezone('utc', now())));
  if not (distance_ok and accuracy_ok) then return false; end if;
  perform public.transition_booking_status(booking_uuid, 'arrived', 'arrival GPS verification passed');
  return true;
end;
$$;

create or replace function public.create_dispatch_assignments(
  booking_uuid uuid,
  candidate_ids uuid[],
  max_candidates integer default 3
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  candidate_id uuid;
  inserted_count integer := 0;
  next_attempt integer;
  eligible boolean;
begin
  select * into b from public.bookings where id = booking_uuid for update;
  if not found or (b.customer_id <> auth.uid() and not public.is_staff()) then raise exception 'not authorized for dispatch'; end if;
  if b.booking_mode <> 'automatic_match' then raise exception 'dispatch is only available for automatic bookings'; end if;
  if b.booking_status not in ('requested', 'dispatching', 'reassigned') then raise exception 'booking is not dispatchable'; end if;

  foreach candidate_id in array coalesce(candidate_ids, '{}'::uuid[]) loop
    exit when inserted_count >= greatest(1, least(max_candidates, 10));
    select exists (
      select 1
      from public.labor_profiles lp
      join public.profiles p on p.id = lp.user_id and p.account_status = 'active'
      join public.labor_services ls on ls.labor_id = lp.user_id and ls.service_id = b.service_id
      join public.booking_locations bl on bl.booking_id = b.id
      where lp.user_id = candidate_id and lp.kyc_status = 'approved' and lp.is_online and lp.is_available
        and exists (select 1 from public.service_areas sa where sa.labor_id = lp.user_id and st_dwithin(sa.center, bl.location, sa.radius_m))
        and not exists (
          select 1 from public.bookings conflict
          where conflict.assigned_labor_id = lp.user_id
            and conflict.booking_status in ('requested','dispatching','accepted','on_the_way','arrived','in_progress','work_done','amount_pending_approval','approved','disputed','payment_pending')
            and conflict.appointment_range && b.appointment_range
        )
    ) into eligible;
    if not eligible then continue; end if;
    select coalesce(max(attempt_number), 0) + 1 into next_attempt from public.booking_assignments where booking_id = b.id;
    insert into public.booking_assignments (booking_id, labor_id, attempt_number, status, response_deadline)
    values (b.id, candidate_id, next_attempt, 'pending', timezone('utc', now()) + make_interval(secs => public.config_int('assignment_response_timeout_seconds', 120)))
    on conflict (booking_id, labor_id) do nothing;
    if found then inserted_count := inserted_count + 1; end if;
  end loop;

  if b.booking_status in ('requested', 'reassigned') and inserted_count > 0 then
    perform set_config('civilconnect.allow_transition', 'on', true);
    update public.bookings set booking_status = 'dispatching' where id = b.id;
    insert into public.booking_status_history (booking_id, previous_status, next_status, actor_id, reason, metadata)
    values (b.id, b.booking_status, 'dispatching', auth.uid(), 'automatic dispatch initiated', jsonb_build_object('candidate_count', inserted_count));
  end if;
  return inserted_count;
end;
$$;

create or replace function public.get_booking_dispatch_context(booking_uuid uuid)
returns table (
  id uuid,
  service_id uuid,
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  booking_mode public.booking_mode,
  booking_status public.booking_status,
  latitude numeric,
  longitude numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select b.id, b.service_id, b.scheduled_start, b.scheduled_end, b.booking_mode, b.booking_status,
         st_y(bl.location::geometry)::numeric, st_x(bl.location::geometry)::numeric
  from public.bookings b
  join public.booking_locations bl on bl.booking_id = b.id
  where b.id = booking_uuid and (b.customer_id = auth.uid() or public.is_staff());
$$;

create or replace function public.dispatch_expired_assignments()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  expired_count integer := 0;
  assignment_row record;
  booking_row record;
begin
  for assignment_row in
    select ba.id, ba.booking_id
    from public.booking_assignments ba
    where ba.status = 'pending' and ba.response_deadline is not null and ba.response_deadline <= timezone('utc', now())
    for update skip locked
  loop
    update public.booking_assignments
    set status = 'expired', responded_at = timezone('utc', now()), expiry_reason = 'scheduled expiry worker'
    where id = assignment_row.id;
    expired_count := expired_count + 1;
  end loop;
  for booking_row in
    select b.id, b.booking_status
    from public.bookings b
    where b.booking_status = 'dispatching'
      and exists (select 1 from public.booking_assignments ba where ba.booking_id = b.id)
      and not exists (select 1 from public.booking_assignments ba where ba.booking_id = b.id and ba.status = 'pending')
    for update skip locked
  loop
    perform set_config('civilconnect.allow_transition', 'on', true);
    update public.bookings set booking_status = 'reassigned' where id = booking_row.id;
    insert into public.booking_status_history (booking_id, previous_status, next_status, reason, metadata)
    values (booking_row.id, booking_row.booking_status, 'reassigned', 'all dispatch attempts expired', '{}'::jsonb);
  end loop;
  return expired_count;
end;
$$;

revoke execute on function public.respond_to_booking_assignment(uuid, boolean, text) from public, anon;
grant execute on function public.respond_to_booking_assignment(uuid, boolean, text) to authenticated;
revoke execute on function public.issue_start_otp(uuid) from public, anon;
grant execute on function public.issue_start_otp(uuid) to authenticated;
revoke execute on function public.publish_live_location(uuid, numeric, numeric, numeric, numeric, numeric, boolean) from public, anon;
grant execute on function public.publish_live_location(uuid, numeric, numeric, numeric, numeric, numeric, boolean) to authenticated;
revoke execute on function public.verify_arrival(uuid, numeric, numeric, numeric) from public, anon;
grant execute on function public.verify_arrival(uuid, numeric, numeric, numeric) to authenticated;
revoke execute on function public.create_dispatch_assignments(uuid, uuid[], integer) from public, anon;
grant execute on function public.create_dispatch_assignments(uuid, uuid[], integer) to authenticated;
revoke execute on function public.get_booking_dispatch_context(uuid) from public, anon;
grant execute on function public.get_booking_dispatch_context(uuid) to authenticated;
revoke execute on function public.dispatch_expired_assignments() from public, anon, authenticated;
grant execute on function public.dispatch_expired_assignments() to service_role;

do $$
declare
  publication_exists boolean;
  realtime_table text;
begin
  select exists(select 1 from pg_publication where pubname = 'supabase_realtime') into publication_exists;
  if publication_exists then
    foreach realtime_table in array array[
      'bookings', 'booking_status_history', 'booking_assignments', 'labor_live_location',
      'booking_amount_proposals', 'payments', 'notifications', 'chat_messages',
      'cash_settlements', 'professional_payouts'
    ] loop
      if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = realtime_table
      ) then
        execute format('alter publication supabase_realtime add table public.%I', realtime_table);
      end if;
    end loop;
  end if;
end;
$$;
