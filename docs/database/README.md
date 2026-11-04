# Supabase database foundation

## Migration order

1. `20261027000000_extensions_enums_identity.sql` — extensions, enums, identity, catalog and availability.
2. `20261027000001_booking_finance_support.sql` — bookings, quote workflow, finance, support and safety.
3. `20261027000002_functions_and_rls.sql` — authorization helpers, transactional functions, state transition guard and RLS.
4. `supabase/seed.sql` — development catalog/configuration only.

## Local commands

Install the Supabase CLI, start Docker, then run:

```bash
supabase start
supabase db reset
supabase migration list
```

The migrations are designed for a Supabase project with `auth.users` available. Apply them to a fresh development project first, then staging, and finally production after reviewing generated SQL and configuring secrets outside the database.

## Security boundaries

- Client apps may read only rows permitted by RLS and call the explicitly granted authenticated RPCs.
- Admin and financial operations must run through authenticated Supabase Edge Functions using server-side authorization and audit reasons.
- Service-role keys, Razorpay secrets, FCM credentials, and Storage signing credentials must never be placed in Flutter, Next.js browser code, seed data, or migrations.
- KYC and job media should use private Storage buckets; `storage_path` is metadata, not a public URL.

## Known Phase 2 integration points

- Edge Functions must implement server-side quote calculation and create proposals; the database stores the calculation and freezes it on approval.
- Razorpay order creation, signature verification, webhook processing, refunds, deposits and payouts are Phase 4 operations. Phase 2 stores their provider identifiers and idempotency boundaries.
- Background jobs must expire assignments, escalate disputes, retry notifications, and reconcile provider records.
- Tax, KYC document requirements, payout arrangement, retention periods, and cancellation penalties remain configuration/legal review items.
