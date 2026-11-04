-- CivilConnect development seed.
-- No real users, credentials, tax rates, or payment credentials are included.

insert into public.app_config (key, value, description)
values
  ('minimum_booking_lead_minutes', '30'::jsonb, 'Server-enforced minimum advance booking time.'),
  ('maximum_advance_booking_days', '30'::jsonb, 'Maximum future booking window for development.'),
  ('assignment_response_timeout_seconds', '120'::jsonb, 'Professional booking request response timeout.'),
  ('cash_exposure_limit_paise', '500000'::jsonb, 'Outstanding platform dues threshold: INR 5,000.'),
  ('cash_exposure_warning_percent', '80'::jsonb, 'Warning threshold as a percentage of cash exposure limit.'),
  ('require_phone_verification_for_booking', '1'::jsonb, 'Phone verification is required before booking.'),
  ('quote_revision_limit', '2'::jsonb, 'Maximum quote revisions before escalation.'),
  ('quote_dispute_escalation_minutes', '15'::jsonb, 'Initial quote dispute escalation period.'),
  ('arrival_geofence_radius_m', '150'::jsonb, 'Initial arrival verification radius; tune with operational data.'),
  ('maximum_arrival_accuracy_m', '100'::jsonb, 'Maximum accepted GPS accuracy for arrival verification.'),
  ('quote_review_threshold_bps', '2500'::jsonb, 'Development review threshold above the service estimate range.'),
  ('tax_rate_bps', '0'::jsonb, 'Development placeholder. Configure only after Indian tax review.')
on conflict (key) do update set value = excluded.value, description = excluded.description, updated_at = timezone('utc', now());

insert into public.service_categories (slug, name, description, icon_name, sort_order)
values
  ('plumbing', 'Plumbing', 'Leaks, fittings, drainage, and water-line repairs.', 'plumbing', 1),
  ('electrical', 'Electrical', 'Switches, wiring, fixtures, fans, and electrical repairs.', 'bolt', 2),
  ('cleaning', 'Cleaning', 'Home, kitchen, bathroom, and deep-cleaning services.', 'cleaning_services', 3),
  ('carpentry', 'Carpentry', 'Furniture repair, installation, and custom carpentry.', 'carpenter', 4),
  ('painting', 'Painting', 'Interior touch-ups, walls, and painting preparation.', 'format_paint', 5),
  ('ac-maintenance', 'AC maintenance', 'AC servicing, installation, and troubleshooting.', 'ac_unit', 6)
on conflict (slug) do update set name = excluded.name, description = excluded.description, icon_name = excluded.icon_name, sort_order = excluded.sort_order, status = 'active';

insert into public.services (category_id, slug, name, description, typical_duration_minutes, estimate_min_paise, estimate_max_paise, visiting_charge_policy)
select sc.id, seed.slug, seed.name, seed.description, seed.duration_minutes, seed.min_paise, seed.max_paise, seed.visiting_policy
from (values
  ('plumbing', 'tap-repair', 'Tap repair', 'Repair or replace leaking taps and fittings.', 60, 15000::bigint, 60000::bigint, 'professional_quote'),
  ('plumbing', 'drainage-repair', 'Drainage repair', 'Unblock and repair common drainage issues.', 90, 25000::bigint, 120000::bigint, 'professional_quote'),
  ('electrical', 'switch-socket-repair', 'Switch and socket repair', 'Repair or replace switches, sockets, and minor wiring.', 60, 15000::bigint, 80000::bigint, 'professional_quote'),
  ('electrical', 'fan-installation', 'Fan installation', 'Install or replace ceiling and exhaust fans.', 90, 25000::bigint, 100000::bigint, 'professional_quote'),
  ('cleaning', 'home-deep-cleaning', 'Home deep cleaning', 'Deep cleaning for rooms, kitchens, and common areas.', 180, 80000::bigint, 350000::bigint, 'professional_quote'),
  ('carpentry', 'furniture-repair', 'Furniture repair', 'Repair and adjust common household furniture.', 120, 30000::bigint, 200000::bigint, 'professional_quote'),
  ('painting', 'wall-touch-up', 'Wall touch-up', 'Small-area wall preparation and painting.', 120, 50000::bigint, 250000::bigint, 'professional_quote'),
  ('ac-maintenance', 'ac-service', 'AC service', 'Routine AC cleaning and maintenance.', 90, 35000::bigint, 180000::bigint, 'professional_quote')
) as seed(category_slug, slug, name, description, duration_minutes, min_paise, max_paise, visiting_policy)
join public.service_categories sc on sc.slug = seed.category_slug
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  typical_duration_minutes = excluded.typical_duration_minutes,
  estimate_min_paise = excluded.estimate_min_paise,
  estimate_max_paise = excluded.estimate_max_paise,
  visiting_charge_policy = excluded.visiting_charge_policy,
  status = 'active';

insert into public.service_price_guide_items (service_id, name, description, suggested_min_paise, suggested_max_paise, is_add_on)
select s.id, guide.name, guide.description, guide.min_paise, guide.max_paise, guide.is_add_on
from (values
  ('tap-repair', 'Standard tap replacement', 'Replacement of a standard tap excluding customer-selected premium hardware.', 8000::bigint, 30000::bigint, true),
  ('switch-socket-repair', 'Switch/socket replacement', 'Replacement of a standard switch or socket.', 5000::bigint, 25000::bigint, true),
  ('home-deep-cleaning', 'Kitchen deep clean', 'Optional kitchen-focused deep-cleaning add-on.', 25000::bigint, 100000::bigint, true),
  ('ac-service', 'Gas top-up', 'Requires evidence and customer approval before charging.', 50000::bigint, 150000::bigint, true)
) as guide(service_slug, name, description, min_paise, max_paise, is_add_on)
join public.services s on s.slug = guide.service_slug
on conflict do nothing;

insert into public.service_pricing (
  scope, version_number, currency, commission_rate_bps, minimum_commission_paise,
  maximum_commission_paise, fixed_platform_fee_paise, tax_rate_bps,
  commission_on_materials, commission_on_visiting_charge, material_taxable, effective_from
)
select 'global', 1, 'INR', 0, null, null, 0, 0, false, true, true, timezone('utc', now())
where not exists (select 1 from public.service_pricing where scope = 'global' and version_number = 1);

insert into public.ledger_accounts (code, name, account_type)
values
  ('revenue:commission', 'Platform commission revenue', 'revenue'),
  ('revenue:fixed-fee', 'Fixed platform fee revenue', 'revenue'),
  ('liability:tax', 'Tax liabilities', 'liability'),
  ('asset:platform-bank', 'Platform bank account', 'asset'),
  ('expense:gateway-fees', 'Payment gateway fees', 'expense')
on conflict (code) do nothing;

insert into public.policy_versions (policy_type, version, content, effective_from)
values
  ('cancellation', 'development-1', '{"no_upfront_charge":true,"customer_free_until_on_the_way":true,"requires_admin_review":true}'::jsonb, timezone('utc', now())),
  ('privacy', 'development-1', '{"status":"draft","requires_legal_review":true}'::jsonb, timezone('utc', now())),
  ('payment', 'development-1', '{"client_callback_is_not_authoritative":true,"provider":"razorpay"}'::jsonb, timezone('utc', now()))
on conflict (policy_type, version) do nothing;
