-- CivilConnect Phase 2 / migration 3
-- Authorization helpers, state transitions, critical transactional functions, and RLS.

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

create or replace function public.is_booking_participant(booking_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_staff() or exists (
    select 1 from public.bookings b
    where b.id = booking_uuid
      and (b.customer_id = auth.uid() or b.selected_labor_id = auth.uid() or b.assigned_labor_id = auth.uid())
  );
$$;

-- Every application table is protected by RLS. Privileged writes are performed
-- through security-definer functions or an authenticated Edge Function.
do $$
declare
  table_record record;
begin
  for table_record in
    select tablename from pg_tables
    where schemaname = 'public'
      and tablename not in ('spatial_ref_sys', 'geography_columns', 'geometry_columns')
  loop
    begin
      execute format('alter table public.%I enable row level security', table_record.tablename);
    exception when others then
      -- Skip internal/extension tables where current role lacks ownership
      null;
    end;
  end loop;
end;
$$;

create policy profiles_select_self_or_staff on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_staff());
create policy profiles_update_self_or_staff on public.profiles
  for update to authenticated using (id = auth.uid() or public.is_staff())
  with check (id = auth.uid() or public.is_staff());

create policy customer_profiles_select_self_or_staff on public.customer_profiles
  for select to authenticated using (user_id = auth.uid() or public.is_staff());
create policy customer_profiles_update_self_or_staff on public.customer_profiles
  for update to authenticated using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid() or public.is_staff());

create policy labor_profiles_select_self_or_staff on public.labor_profiles
  for select to authenticated using (user_id = auth.uid() or public.is_staff());
create policy labor_profiles_insert_self on public.labor_profiles
  for insert to authenticated with check (user_id = auth.uid() and kyc_status = 'not_started');
create policy labor_profiles_update_self_or_staff on public.labor_profiles
  for update to authenticated using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid() or public.is_staff());

create policy labor_kyc_select_owner_or_staff on public.labor_kyc
  for select to authenticated using (labor_id = auth.uid() or public.is_staff());
create policy labor_kyc_insert_owner on public.labor_kyc
  for insert to authenticated with check (labor_id = auth.uid() and status = 'submitted');
create policy labor_kyc_update_staff on public.labor_kyc
  for update to authenticated using (public.is_staff()) with check (public.is_staff());

create policy admin_roles_staff_only on public.admin_roles
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy device_tokens_owner_or_staff on public.device_tokens
  for all to authenticated using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid() or public.is_staff());

create policy service_categories_public_read on public.service_categories
  for select to anon, authenticated using (status = 'active' or public.is_staff());
create policy service_categories_staff_write on public.service_categories
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy services_public_read on public.services
  for select to anon, authenticated using (status = 'active' or public.is_staff());
create policy services_staff_write on public.services
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy service_pricing_current_read on public.service_pricing
  for select to authenticated using (
    public.is_staff() or (effective_from <= timezone('utc', now()) and (effective_to is null or effective_to > timezone('utc', now())))
  );
create policy service_pricing_staff_write on public.service_pricing
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy service_guides_public_read on public.service_price_guide_items
  for select to anon, authenticated using (status = 'active' or public.is_staff());
create policy service_guides_staff_write on public.service_price_guide_items
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy labor_services_public_read on public.labor_services
  for select to anon, authenticated using (
    public.is_staff() or labor_id = auth.uid() or exists (
      select 1 from public.labor_profiles lp
      join public.profiles p on p.id = lp.user_id
      where lp.user_id = labor_id and lp.kyc_status = 'approved' and p.account_status = 'active'
    )
  );
create policy labor_services_owner_write on public.labor_services
  for all to authenticated using (labor_id = auth.uid() or public.is_staff())
  with check (labor_id = auth.uid() or public.is_staff());

create policy labor_availability_owner_or_staff on public.labor_availability
  for all to authenticated using (labor_id = auth.uid() or public.is_staff())
  with check (labor_id = auth.uid() or public.is_staff());
create policy labor_leaves_owner_or_staff on public.labor_leaves
  for all to authenticated using (labor_id = auth.uid() or public.is_staff())
  with check (labor_id = auth.uid() or public.is_staff());
create policy service_areas_owner_or_staff on public.service_areas
  for all to authenticated using (labor_id = auth.uid() or public.is_staff())
  with check (labor_id = auth.uid() or public.is_staff());

create policy saved_addresses_owner_or_staff on public.saved_addresses
  for all to authenticated using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid() or public.is_staff());
create policy saved_professionals_owner_or_staff on public.saved_professionals
  for all to authenticated using (customer_id = auth.uid() or public.is_staff())
  with check (customer_id = auth.uid() or public.is_staff());

create policy bookings_participant_or_staff_read on public.bookings
  for select to authenticated using (public.is_booking_participant(id));
create policy bookings_staff_update on public.bookings
  for update to authenticated using (public.is_staff()) with check (public.is_staff());

create policy booking_locations_customer_or_accepted_professional on public.booking_locations
  for select to authenticated using (
    exists (select 1 from public.bookings b where b.id = booking_id and b.customer_id = auth.uid()) or
    exists (select 1 from public.bookings b where b.id = booking_id and b.assigned_labor_id = auth.uid()
      and b.booking_status in ('accepted','on_the_way','arrived','in_progress','work_done','amount_pending_approval','approved','disputed','payment_pending','paid','closed','rated')) or
    public.is_staff()
  );

create policy booking_media_participant_read on public.booking_media
  for select to authenticated using (public.is_booking_participant(booking_id));
create policy booking_media_customer_or_assigned_insert on public.booking_media
  for insert to authenticated with check (
    uploaded_by = auth.uid() and (
      exists (select 1 from public.bookings b where b.id = booking_id and b.customer_id = auth.uid()) or
      exists (select 1 from public.bookings b where b.id = booking_id and b.assigned_labor_id = auth.uid() and b.booking_status not in ('requested','dispatching','rejected','expired','cancelled'))
    )
  );

create policy booking_status_history_participant_read on public.booking_status_history
  for select to authenticated using (public.is_booking_participant(booking_id));
create policy booking_assignments_participant_read on public.booking_assignments
  for select to authenticated using (
    labor_id = auth.uid() or exists (select 1 from public.bookings b where b.id = booking_id and b.customer_id = auth.uid()) or public.is_staff()
  );

create policy labor_live_location_professional_write on public.labor_live_location
  for all to authenticated using (labor_id = auth.uid() or public.is_staff())
  with check (labor_id = auth.uid() or public.is_staff());
create policy labor_live_location_authorized_customer_read on public.labor_live_location
  for select to authenticated using (
    public.is_staff() or labor_id = auth.uid() or exists (
      select 1 from public.bookings b
      where b.id = active_booking_id and b.customer_id = auth.uid()
        and b.booking_status in ('on_the_way','arrived','in_progress','work_done','amount_pending_approval','approved','disputed','payment_pending','paid','closed','rated')
    )
  );

create policy work_sessions_participant_read on public.work_sessions
  for select to authenticated using (labor_id = auth.uid() or exists (select 1 from public.bookings b where b.id = booking_id and b.customer_id = auth.uid()) or public.is_staff());
create policy booking_verifications_participant_read on public.booking_verifications
  for select to authenticated using (public.is_booking_participant(booking_id));

create policy quote_participant_read on public.booking_amount_proposals
  for select to authenticated using (public.is_booking_participant(booking_id));
create policy quote_line_participant_read on public.quote_line_items
  for select to authenticated using (exists (select 1 from public.booking_amount_proposals q where q.id = proposal_id and public.is_booking_participant(q.booking_id)));

create policy cancellation_participant_read on public.cancellation_penalties
  for select to authenticated using (public.is_booking_participant(booking_id));

create policy payments_participant_read on public.payments
  for select to authenticated using (customer_id = auth.uid() or exists (select 1 from public.bookings b where b.id = booking_id and b.assigned_labor_id = auth.uid()) or public.is_staff());
create policy provider_orders_customer_read on public.payment_provider_orders
  for select to authenticated using (exists (select 1 from public.payments p where p.id = payment_id and (p.customer_id = auth.uid() or public.is_staff())));
create policy provider_events_staff_only on public.payment_provider_events
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy refunds_payment_owner_or_staff on public.refunds
  for select to authenticated using (exists (select 1 from public.payments p where p.id = payment_id and p.customer_id = auth.uid()) or public.is_staff());

create policy ledger_staff_only on public.ledger_transactions
  for select to authenticated using (public.is_staff());
create policy ledger_entries_staff_only on public.ledger_entries
  for select to authenticated using (public.is_staff());
create policy ledger_accounts_staff_or_owner_read on public.ledger_accounts
  for select to authenticated using (public.is_staff() or owner_user_id = auth.uid());

create policy receivables_professional_or_staff_read on public.platform_receivables
  for select to authenticated using (professional_id = auth.uid() or public.is_staff());
create policy cash_settlements_professional_or_staff_read on public.cash_settlements
  for select to authenticated using (professional_id = auth.uid() or public.is_staff());
create policy payouts_professional_or_staff_read on public.professional_payouts
  for select to authenticated using (professional_id = auth.uid() or public.is_staff());
create policy reconciliation_staff_only on public.payment_reconciliations
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy adjustments_staff_only on public.financial_adjustments
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy invoices_customer_or_professional_read on public.invoices
  for select to authenticated using (customer_id = auth.uid() or exists (select 1 from public.bookings b where b.id = booking_id and b.assigned_labor_id = auth.uid()) or public.is_staff());

create policy ratings_visible_read on public.ratings
  for select to anon, authenticated using (is_visible = true or reviewer_id = auth.uid() or reviewee_id = auth.uid() or public.is_staff());
create policy ratings_eligible_insert on public.ratings
  for insert to authenticated with check (
    reviewer_id = auth.uid() and exists (
      select 1 from public.bookings b
      where b.id = booking_id and b.booking_status in ('closed','rated')
        and b.payment_status = 'captured'
        and (b.customer_id = auth.uid() or b.assigned_labor_id = auth.uid())
    )
  );

create policy notifications_owner_or_staff on public.notifications
  for all to authenticated using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid() or public.is_staff());

create policy chat_threads_participant_read on public.chat_threads
  for select to authenticated using (public.is_booking_participant(booking_id));
create policy chat_messages_participant_read_write on public.chat_messages
  for all to authenticated using (sender_id = auth.uid() or exists (select 1 from public.chat_threads t where t.id = thread_id and public.is_booking_participant(t.booking_id)))
  with check (sender_id = auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and public.is_booking_participant(t.booking_id)));

create policy disputes_participant_read on public.disputes
  for select to authenticated using (public.is_booking_participant(booking_id));
create policy disputes_customer_insert on public.disputes
  for insert to authenticated with check (opened_by = auth.uid() and exists (select 1 from public.bookings b where b.id = booking_id and b.customer_id = auth.uid()));
create policy dispute_events_participant_read on public.dispute_events
  for select to authenticated using (exists (select 1 from public.disputes d where d.id = dispute_id and public.is_booking_participant(d.booking_id)));

create policy support_tickets_creator_or_staff on public.support_tickets
  for select to authenticated using (created_by = auth.uid() or assigned_to = auth.uid() or public.is_staff());
create policy support_tickets_creator_insert on public.support_tickets
  for insert to authenticated with check (created_by = auth.uid());
create policy support_tickets_staff_update on public.support_tickets
  for update to authenticated using (assigned_to = auth.uid() or public.is_staff()) with check (assigned_to = auth.uid() or public.is_staff());

create policy active_promos_public_read on public.promo_codes
  for select to anon, authenticated using (is_active and starts_at <= timezone('utc', now()) and (ends_at is null or ends_at > timezone('utc', now())) or public.is_staff());
create policy promos_staff_write on public.promo_codes
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy redemptions_customer_or_staff on public.promotional_redemptions
  for select to authenticated using (customer_id = auth.uid() or public.is_staff());

create policy emergency_contacts_owner_or_staff on public.emergency_contacts
  for all to authenticated using (user_id = auth.uid() or public.is_staff()) with check (user_id = auth.uid() or public.is_staff());
create policy sos_participant_or_staff on public.sos_events
  for select to authenticated using (raised_by = auth.uid() or public.is_staff() or public.is_booking_participant(booking_id));
create policy sos_owner_insert on public.sos_events
  for insert to authenticated with check (raised_by = auth.uid());

create policy audit_staff_only on public.audit_logs
  for select to authenticated using (public.is_staff());
create policy app_config_staff_only on public.app_config
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy consents_owner_or_staff on public.consents
  for all to authenticated using (user_id = auth.uid() or public.is_staff()) with check (user_id = auth.uid() or public.is_staff());
create policy deletion_owner_or_staff on public.account_deletion_requests
  for all to authenticated using (user_id = auth.uid() or public.is_staff()) with check (user_id = auth.uid() or public.is_staff());
create policy active_policy_versions_public_read on public.policy_versions
  for select to anon, authenticated using (effective_from <= timezone('utc', now()) and (effective_to is null or effective_to > timezone('utc', now())) or public.is_staff());
create policy policy_versions_staff_write on public.policy_versions
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

-- RPC execute grants are applied after all function definitions below.

create or replace function public.has_admin_role(required_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_roles
    where user_id = auth.uid() and role = required_role and revoked_at is null
  );
$$;

create or replace function public.is_profile_owner(profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select profile_id = auth.uid();
$$;

create or replace function public.config_int(config_key text, fallback integer)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select (value #>> '{}')::integer from public.app_config
     where key = config_key
       and effective_from <= timezone('utc', now())
       and (effective_to is null or effective_to > timezone('utc', now()))
     order by effective_from desc limit 1),
    fallback
  );
$$;

create or replace function public.protect_profile_privileged_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.is_staff() then
    if new.primary_role is distinct from old.primary_role
       or new.account_status is distinct from old.account_status
       or new.phone_verified_at is distinct from old.phone_verified_at
       or new.email_verified_at is distinct from old.email_verified_at
       or new.deleted_at is distinct from old.deleted_at then
      raise exception 'privileged profile fields can only be changed by authorized backend operations';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_protect_privileged_fields
  before update on public.profiles
  for each row execute function public.protect_profile_privileged_fields();

create or replace function public.protect_labor_privileged_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.is_staff() then
    if new.kyc_status is distinct from old.kyc_status
       or new.average_rating is distinct from old.average_rating
       or new.rating_count is distinct from old.rating_count
       or new.completed_job_count is distinct from old.completed_job_count
       or new.is_background_checked is distinct from old.is_background_checked
       or new.payout_profile_provider_id is distinct from old.payout_profile_provider_id
       or new.payout_profile_status is distinct from old.payout_profile_status then
      raise exception 'professional verification and financial fields require an authorized backend operation';
    end if;
  end if;
  return new;
end;
$$;

create trigger labor_profiles_protect_privileged_fields
  before update on public.labor_profiles
  for each row execute function public.protect_labor_privileged_fields();

create or replace function public.prevent_direct_booking_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.booking_status is distinct from old.booking_status
     and coalesce(current_setting('civilconnect.allow_transition', true), 'off') <> 'on' then
    raise exception 'booking status transitions must use an authorized database function';
  end if;
  return new;
end;
$$;

create trigger bookings_status_transition_guard
  before update on public.bookings
  for each row execute function public.prevent_direct_booking_status_change();

create or replace function public.transition_booking_status(
  booking_uuid uuid,
  next_status public.booking_status,
  transition_reason text default null,
  transition_metadata jsonb default '{}'::jsonb
)
returns public.booking_status
language plpgsql
security definer
set search_path = public
as $$
declare
  current_booking public.bookings%rowtype;
  actor uuid := auth.uid();
  allowed boolean := false;
begin
  if actor is null then
    raise exception 'authentication required';
  end if;

  select * into current_booking from public.bookings where id = booking_uuid for update;
  if not found then
    raise exception 'booking not found';
  end if;

  if not public.is_staff()
     and current_booking.customer_id <> actor
     and coalesce(current_booking.selected_labor_id, current_booking.assigned_labor_id) <> actor then
    raise exception 'not authorized for booking';
  end if;

  allowed := case current_booking.booking_status
    when 'requested' then next_status in ('dispatching', 'accepted', 'rejected', 'expired', 'cancelled', 'reassigned')
    when 'dispatching' then next_status in ('accepted', 'rejected', 'expired', 'cancelled', 'reassigned')
    when 'accepted' then next_status in ('on_the_way', 'cancelled', 'no_show')
    when 'on_the_way' then next_status in ('arrived', 'cancelled', 'no_show')
    when 'arrived' then next_status in ('in_progress', 'cancelled', 'no_show')
    when 'in_progress' then next_status in ('work_done', 'cancelled', 'no_show')
    when 'work_done' then next_status in ('amount_pending_approval', 'cancelled')
    when 'amount_pending_approval' then next_status in ('approved', 'disputed', 'cancelled')
    when 'approved' then next_status in ('payment_pending', 'disputed', 'cancelled')
    when 'disputed' then next_status in ('approved', 'amount_pending_approval', 'cancelled')
    when 'payment_pending' then next_status in ('paid', 'refund_pending', 'cancelled')
    when 'paid' then next_status in ('closed', 'refund_pending')
    when 'closed' then next_status = 'rated'
    when 'rated' then false
    when 'refund_pending' then next_status = 'refunded'
    else false
  end;

  if not allowed then
    raise exception 'invalid booking transition: % -> %', current_booking.booking_status, next_status;
  end if;

  if next_status in ('accepted', 'on_the_way', 'arrived', 'in_progress', 'work_done')
     and not public.is_staff()
     and actor <> coalesce(current_booking.assigned_labor_id, current_booking.selected_labor_id) then
    raise exception 'only the assigned professional can advance this booking';
  end if;

  perform set_config('civilconnect.allow_transition', 'on', true);
  update public.bookings
  set booking_status = next_status,
      work_completed_at = case when next_status = 'work_done' then timezone('utc', now()) else work_completed_at end,
      closed_at = case when next_status in ('closed', 'rated') then timezone('utc', now()) else closed_at end
  where id = booking_uuid;

  insert into public.booking_status_history (booking_id, previous_status, next_status, actor_id, reason, metadata)
  values (booking_uuid, current_booking.booking_status, next_status, actor, transition_reason, coalesce(transition_metadata, '{}'::jsonb));

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, reason, metadata)
  values (actor, 'booking_status_transition', 'booking', booking_uuid, transition_reason,
          jsonb_build_object('previous_status', current_booking.booking_status, 'next_status', next_status));

  return next_status;
end;
$$;

create or replace function public.create_booking(
  service_uuid uuid,
  mode public.booking_mode,
  selected_professional_uuid uuid,
  requested_start timestamptz,
  requested_end timestamptz,
  problem text,
  latitude numeric,
  longitude numeric,
  accuracy_m numeric,
  address_snapshot text,
  flat_number text default null,
  landmark text default null,
  directions text default null,
  idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  booking_uuid uuid;
  service_row public.services%rowtype;
  booking_start timestamptz;
  booking_end timestamptz;
  initial_status public.booking_status;
  location_point geography;
  existing_booking uuid;
begin
  if actor is null then raise exception 'authentication required'; end if;
  if not exists (select 1 from public.customer_profiles where user_id = actor) then
    raise exception 'customer profile required';
  end if;
  if not exists (select 1 from public.profiles where id = actor and phone_verified_at is not null and account_status = 'active')
     and public.config_int('require_phone_verification_for_booking', 1) = 1 then
    raise exception 'verified phone number required before booking';
  end if;
  if mode = 'selected_professional' and selected_professional_uuid is null then
    raise exception 'selected professional required';
  end if;
  if mode = 'automatic_match' and selected_professional_uuid is not null then
    raise exception 'automatic matching cannot include a selected professional';
  end if;
  if latitude not between -90 and 90 or longitude not between -180 and 180 then
    raise exception 'valid GPS coordinates required';
  end if;
  if accuracy_m is not null and accuracy_m < 0 then raise exception 'invalid GPS accuracy'; end if;

  select * into service_row from public.services where id = service_uuid and status = 'active';
  if not found then raise exception 'active service not found'; end if;

  booking_start := requested_start;
  booking_end := requested_end;
  if booking_start < timezone('utc', now()) + make_interval(mins => public.config_int('minimum_booking_lead_minutes', 30)) then
    raise exception 'booking must be at least % minutes from server time', public.config_int('minimum_booking_lead_minutes', 30);
  end if;
  if booking_start > timezone('utc', now()) + make_interval(days => public.config_int('maximum_advance_booking_days', 30)) then
    raise exception 'booking exceeds the maximum advance-booking window';
  end if;
  if booking_end <= booking_start then raise exception 'booking end must be after booking start'; end if;
  if extract(epoch from (booking_end - booking_start)) / 60 > 1440 then raise exception 'booking duration is too long'; end if;

  location_point := st_setsrid(st_makepoint(longitude, latitude), 4326)::geography;

  if selected_professional_uuid is not null then
    if not exists (
      select 1
      from public.labor_profiles lp
      join public.labor_services ls on ls.labor_id = lp.user_id and ls.service_id = service_uuid
      where lp.user_id = selected_professional_uuid
        and lp.kyc_status = 'approved'
        and lp.is_online and lp.is_available
        and exists (select 1 from public.service_areas sa where sa.labor_id = lp.user_id and st_dwithin(sa.center, location_point, sa.radius_m))
    ) then
      raise exception 'selected professional is not currently eligible for this service and location';
    end if;
  end if;

  if idempotency_key is not null then
    select id into existing_booking from public.audit_logs
    where actor_id = actor and action = 'booking_create_idempotency' and metadata ->> 'idempotency_key' = idempotency_key
    order by created_at desc limit 1;
    if existing_booking is not null then return existing_booking; end if;
  end if;

  initial_status := case when mode = 'automatic_match' then 'dispatching' else 'requested' end;
  insert into public.bookings (
    customer_id, service_id, selected_labor_id, assigned_labor_id, booking_mode, booking_status,
    scheduled_start, scheduled_end, estimated_duration_minutes, problem_description,
    estimate_snapshot, cancellation_policy_snapshot
  ) values (
    actor, service_uuid, selected_professional_uuid, selected_professional_uuid, mode, initial_status,
    booking_start, booking_end, service_row.typical_duration_minutes, coalesce(problem, ''),
    jsonb_build_object('min_paise', service_row.estimate_min_paise, 'max_paise', service_row.estimate_max_paise),
    jsonb_build_object('no_upfront_charge', true)
  ) returning id into booking_uuid;

  insert into public.booking_locations (booking_id, location, accuracy_m, address_snapshot, flat_number, landmark, directions)
  values (booking_uuid, location_point, accuracy_m, coalesce(address_snapshot, ''), flat_number, landmark, directions);

  if selected_professional_uuid is not null then
    insert into public.booking_assignments (booking_id, labor_id, attempt_number, status, response_deadline)
    values (booking_uuid, selected_professional_uuid, 1, 'pending', timezone('utc', now()) + make_interval(secs => public.config_int('assignment_response_timeout_seconds', 120)));
  end if;

  insert into public.booking_status_history (booking_id, previous_status, next_status, actor_id, metadata)
  values (booking_uuid, null, initial_status, actor, jsonb_build_object('server_time', timezone('utc', now())));

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (actor, 'booking_create_idempotency', 'booking', booking_uuid, jsonb_build_object('idempotency_key', idempotency_key));

  return booking_uuid;
end;
$$;

create or replace function public.find_nearby_professionals(
  service_uuid uuid,
  latitude numeric,
  longitude numeric,
  requested_start timestamptz,
  requested_end timestamptz,
  result_limit integer default 20
)
returns table (
  professional_id uuid,
  professional_name text,
  avatar_path text,
  rating numeric,
  rating_count integer,
  completed_jobs integer,
  distance_m numeric,
  visiting_charge_hint_paise bigint,
  ranking_score numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with request_point as (
    select st_setsrid(st_makepoint(longitude, latitude), 4326)::geography as point
  ),
  candidates as (
    select distinct on (lp.user_id)
      lp.user_id as professional_id,
      p.full_name as professional_name,
      p.avatar_path,
      lp.average_rating as rating,
      lp.rating_count,
      lp.completed_job_count as completed_jobs,
      st_distance(sa.center, rp.point)::numeric as distance_m,
      s.estimate_min_paise as visiting_charge_hint_paise,
      ((lp.rating_count::numeric / (lp.rating_count + 10)) * lp.average_rating +
       (10::numeric / (lp.rating_count + 10)) * 4.2) as ranking_score
    from public.labor_profiles lp
    join public.profiles p on p.id = lp.user_id and p.account_status = 'active'
    join public.labor_services lsm on lsm.labor_id = lp.user_id and lsm.service_id = service_uuid
    join public.services s on s.id = service_uuid and s.status = 'active'
    cross join request_point rp
    join public.service_areas sa on sa.labor_id = lp.user_id and st_dwithin(sa.center, rp.point, sa.radius_m)
    where auth.uid() is not null
      and lp.kyc_status = 'approved' and lp.is_online and lp.is_available
      and not exists (
        select 1 from public.labor_leaves ll
        where ll.labor_id = lp.user_id and ll.status = 'planned'
          and ll.leave_range && tstzrange(requested_start, requested_end, '[)')
      )
      and not exists (
        select 1 from public.bookings b
        where b.assigned_labor_id = lp.user_id
          and b.booking_status in ('requested','dispatching','accepted','on_the_way','arrived','in_progress','work_done','amount_pending_approval','approved','disputed','payment_pending')
          and b.appointment_range && tstzrange(requested_start, requested_end, '[)')
      )
    order by lp.user_id, st_distance(sa.center, rp.point)
  )
  select professional_id, professional_name, avatar_path, rating, rating_count, completed_jobs,
         distance_m, visiting_charge_hint_paise, ranking_score
  from candidates
  order by ranking_score desc, distance_m asc, completed_jobs desc
  limit greatest(1, least(result_limit, 100));
$$;

create or replace function public.verify_start_otp(booking_uuid uuid, otp text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  valid boolean;
begin
  select * into b from public.bookings where id = booking_uuid for update;
  if not found or b.assigned_labor_id <> auth.uid() then raise exception 'not authorized for booking'; end if;
  valid := b.start_otp_hash is not null
    and b.start_otp_expires_at > timezone('utc', now())
    and crypt(otp, b.start_otp_hash) = b.start_otp_hash;
  insert into public.booking_verifications (booking_id, verification_type, actor_id, success, metadata)
  values (booking_uuid, 'start_otp', auth.uid(), valid, jsonb_build_object('server_time', timezone('utc', now())));
  if not valid then return false; end if;
  perform public.transition_booking_status(booking_uuid, 'in_progress', 'customer start OTP verified');
  return true;
end;
$$;

create or replace function public.approve_quote(booking_uuid uuid, proposal_uuid uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  q public.booking_amount_proposals%rowtype;
begin
  select * into b from public.bookings where id = booking_uuid and customer_id = auth.uid() for update;
  if not found then raise exception 'booking not found or unauthorized'; end if;
  select * into q from public.booking_amount_proposals where id = proposal_uuid and booking_id = booking_uuid for update;
  if not found or q.status not in ('submitted', 'resolved') then raise exception 'quote is not awaiting approval'; end if;
  if b.booking_status not in ('amount_pending_approval', 'disputed') then raise exception 'booking is not awaiting quote approval'; end if;

  update public.booking_amount_proposals
  set status = 'approved', approved_at = timezone('utc', now())
  where id = proposal_uuid;
  update public.booking_amount_proposals
  set status = 'rejected'
  where booking_id = booking_uuid and id <> proposal_uuid and status in ('submitted', 'revised');
  update public.bookings set customer_approved_at = timezone('utc', now()) where id = booking_uuid;
  perform public.transition_booking_status(booking_uuid, 'approved', 'customer approved immutable quote');
  return proposal_uuid;
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

create or replace function public.record_cash_collection(
  booking_uuid uuid,
  quoted_amount_paise bigint,
  idempotency_key text,
  customer_confirmed boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings%rowtype;
  q public.booking_amount_proposals%rowtype;
  payment_uuid uuid;
  tx_uuid uuid;
  dues bigint;
  existing_payment uuid;
  professional_uuid uuid;
  earnings_account uuid;
  cash_account uuid;
  commission_account uuid;
  fixed_fee_account uuid;
  tax_account uuid;
  payable_amount bigint;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not customer_confirmed then raise exception 'customer confirmation is required for cash collection'; end if;
  select id into existing_payment from public.payments where idempotency_key = record_cash_collection.idempotency_key;
  if existing_payment is not null then return existing_payment; end if;

  select * into b from public.bookings where id = booking_uuid for update;
  if not found or b.assigned_labor_id <> auth.uid() then raise exception 'not authorized for booking'; end if;
  if b.booking_status <> 'approved' or b.payment_status not in ('pending', 'failed') then raise exception 'booking is not eligible for cash collection'; end if;
  select * into q from public.booking_amount_proposals where booking_id = booking_uuid and status = 'approved' order by revision_number desc limit 1;
  if not found then raise exception 'approved quote required'; end if;
  if quoted_amount_paise <> q.customer_payable_paise then raise exception 'client amount does not match approved backend amount'; end if;

  professional_uuid := b.assigned_labor_id;
  perform pg_advisory_xact_lock(hashtextextended(professional_uuid::text, 0));
  select coalesce(sum(pr.outstanding_amount_paise), 0) into dues
  from public.platform_receivables pr
  where pr.professional_id = professional_uuid and pr.outstanding_amount_paise > 0;
  if dues + q.commission_paise + q.fixed_platform_fee_paise > public.config_int('cash_exposure_limit_paise', 500000) then
    raise exception 'cash exposure limit exceeded';
  end if;

  insert into public.payments (booking_id, customer_id, method, status, amount_paise, idempotency_key, captured_at)
  values (booking_uuid, b.customer_id, 'cash', 'captured', q.customer_payable_paise, record_cash_collection.idempotency_key, timezone('utc', now()))
  returning id into payment_uuid;

  earnings_account := public.ensure_ledger_account('payable:professional:' || professional_uuid, 'Professional earnings payable', 'payable', professional_uuid);
  cash_account := public.ensure_ledger_account('cash:professional:' || professional_uuid, 'Cash collected by professional', 'asset', professional_uuid);
  commission_account := public.ensure_ledger_account('revenue:commission', 'Platform commission revenue', 'revenue');
  fixed_fee_account := public.ensure_ledger_account('revenue:fixed-fee', 'Fixed platform fee revenue', 'revenue');
  tax_account := public.ensure_ledger_account('liability:tax', 'Tax liabilities', 'liability');

  insert into public.ledger_transactions(reference, transaction_type, booking_id, payment_id, source_idempotency_key, created_by)
  values ('cash-collection:' || record_cash_collection.idempotency_key, 'cash_collection', booking_uuid, payment_uuid, record_cash_collection.idempotency_key, auth.uid())
  returning id into tx_uuid;

  insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo)
  values (tx_uuid, cash_account, 'debit', q.customer_payable_paise, 'Gross cash collected by professional');
  if q.professional_earnings_paise > 0 then
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo)
    values (tx_uuid, earnings_account, 'credit', q.professional_earnings_paise, 'Professional earnings');
  end if;
  if q.commission_paise > 0 then
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo)
    values (tx_uuid, commission_account, 'credit', q.commission_paise, 'Platform commission');
  end if;
  if q.fixed_platform_fee_paise > 0 then
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo)
    values (tx_uuid, fixed_fee_account, 'credit', q.fixed_platform_fee_paise, 'Fixed platform fee');
  end if;
  if q.tax_paise > 0 then
    insert into public.ledger_entries(transaction_id, account_id, direction, amount_paise, memo)
    values (tx_uuid, tax_account, 'credit', q.tax_paise, 'Tax liability');
  end if;
  perform public.post_ledger_transaction(tx_uuid);

  insert into public.platform_receivables (professional_id, booking_id, source_payment_id, original_amount_paise, outstanding_amount_paise, due_at)
  values (professional_uuid, booking_uuid, payment_uuid, q.commission_paise + q.fixed_platform_fee_paise,
          q.commission_paise + q.fixed_platform_fee_paise, timezone('utc', now()));
  update public.bookings set payment_status = 'captured', settlement_status = 'pending' where id = booking_uuid;
  perform public.transition_booking_status(booking_uuid, 'payment_pending', 'cash payment pending posting');
  perform public.transition_booking_status(booking_uuid, 'paid', 'verified cash collection');
  if dues + q.commission_paise + q.fixed_platform_fee_paise >= public.config_int('cash_exposure_limit_paise', 500000) * 80 / 100 then
    insert into public.notifications(user_id, booking_id, channel, event_type, title, body, data)
    values (professional_uuid, booking_uuid, 'in_app', 'cash_exposure_warning', 'Settlement recommended',
            'Your outstanding platform dues are approaching the configured cash exposure limit.',
            jsonb_build_object('outstanding_paise', dues + q.commission_paise + q.fixed_platform_fee_paise));
  end if;
  return payment_uuid;
end;
$$;

create or replace function public.professional_financial_summary(professional_uuid uuid default auth.uid())
returns table (
  cash_earnings_paise bigint,
  online_earnings_paise bigint,
  gross_cash_collected_paise bigint,
  outstanding_platform_dues_paise bigint,
  withdrawable_balance_paise bigint,
  pending_payouts_paise bigint,
  cash_exposure_limit_paise bigint,
  cash_restriction boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select sum(q.professional_earnings_paise)::bigint from public.booking_amount_proposals q join public.bookings b on b.id = q.booking_id where b.assigned_labor_id = professional_uuid and q.status = 'approved' and b.payment_status = 'captured' and exists (select 1 from public.payments p where p.booking_id = b.id and p.method = 'cash')), 0::bigint),
    coalesce((select sum(q.professional_earnings_paise)::bigint from public.booking_amount_proposals q join public.bookings b on b.id = q.booking_id where b.assigned_labor_id = professional_uuid and q.status = 'approved' and b.payment_status = 'captured' and exists (select 1 from public.payments p where p.booking_id = b.id and p.method = 'online')), 0::bigint),
    coalesce((select sum(p.amount_paise)::bigint from public.payments p join public.bookings b on b.id = p.booking_id where b.assigned_labor_id = professional_uuid and p.method = 'cash' and p.status = 'captured'), 0::bigint),
    coalesce((select sum(pr.outstanding_amount_paise)::bigint from public.platform_receivables pr where pr.professional_id = professional_uuid), 0::bigint),
    greatest(0::bigint, coalesce((select (coalesce(sum(le.amount_paise) filter (where le.direction = 'credit'), 0) - coalesce(sum(le.amount_paise) filter (where le.direction = 'debit'), 0))::bigint from public.ledger_entries le join public.ledger_accounts la on la.id = le.account_id where la.owner_user_id = professional_uuid and la.account_type = 'payable'), 0::bigint)),
    coalesce((select sum(amount_paise)::bigint from public.professional_payouts where professional_id = professional_uuid and status in ('pending', 'processing')), 0::bigint),
    public.config_int('cash_exposure_limit_paise', 500000),
    coalesce((select sum(pr.outstanding_amount_paise)::bigint from public.platform_receivables pr where pr.professional_id = professional_uuid), 0::bigint) >= public.config_int('cash_exposure_limit_paise', 500000)
  where professional_uuid = auth.uid() or public.is_staff();
$$;

-- RPCs are the only client-facing path for high-risk transitions. Edge Functions
-- should still validate request schemas and supply idempotency keys.
revoke execute on function public.transition_booking_status(uuid, public.booking_status, text, jsonb) from public, anon;
grant execute on function public.transition_booking_status(uuid, public.booking_status, text, jsonb) to authenticated;
revoke execute on function public.create_booking(uuid, public.booking_mode, uuid, timestamptz, timestamptz, text, numeric, numeric, numeric, text, text, text, text, text) from public, anon;
grant execute on function public.create_booking(uuid, public.booking_mode, uuid, timestamptz, timestamptz, text, numeric, numeric, numeric, text, text, text, text, text) to authenticated;
revoke execute on function public.find_nearby_professionals(uuid, numeric, numeric, timestamptz, timestamptz, integer) from public, anon;
grant execute on function public.find_nearby_professionals(uuid, numeric, numeric, timestamptz, timestamptz, integer) to authenticated;
revoke execute on function public.verify_start_otp(uuid, text) from public, anon;
grant execute on function public.verify_start_otp(uuid, text) to authenticated;
revoke execute on function public.approve_quote(uuid, uuid) from public, anon;
grant execute on function public.approve_quote(uuid, uuid) to authenticated;
revoke execute on function public.record_cash_collection(uuid, bigint, text, boolean) from public, anon;
grant execute on function public.record_cash_collection(uuid, bigint, text, boolean) to authenticated;
revoke execute on function public.professional_financial_summary(uuid) from public, anon;
grant execute on function public.professional_financial_summary(uuid) to authenticated;
