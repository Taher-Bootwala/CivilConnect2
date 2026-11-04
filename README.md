# CivilConnect

CivilConnect is an India-focused home-services marketplace built around Flutter and Supabase.

## Current delivery

- **Phase 1:** Architecture and financial/security decisions — `docs/phase-1-architecture.md`
- **Phase 2:** PostgreSQL/PostGIS schema, RLS, state machines, ledger foundation and seed data — `docs/database/README.md`
- **Phase 3:** Supabase Edge Functions for auth-aware profiles, discovery, booking, dispatch, professional onboarding and KYC — `supabase/functions/README.md`
- **Phase 4:** Server-priced quotes, Razorpay verification/webhooks, refunds, cash settlements, payout eligibility and reconciliation — `supabase/migrations/20261027000004_financial_core.sql`
- **Phase 5:** Flutter customer/professional applications with GPS booking, quote/payment flows and native permission configuration.
- **Phase 6:** Responsive Next.js/Tailwind admin control room — `admin-dashboard/`
- **Phase 7:** CI/CD, production operations, security/performance plans, recovery and release checklists — `docs/production-readiness.md`
- **Phase 8:** 12-week roadmap, prioritization and launch gates — `docs/roadmap-12-weeks.md`
- **API contract:** `docs/api/openapi.yaml`
- **Realtime contract:** `docs/api/realtime-events.md`

## Flutter checks

```bash
flutter pub get
flutter analyze
flutter test
```

## Supabase setup

Install the Supabase CLI and Docker, configure a development project, then:

```bash
supabase start
supabase db reset
supabase functions serve create-booking --env-file .env.local
```

Apply the migrations to development first. Use separate Supabase projects and secret stores for staging and production. Never put a service-role key, Razorpay secret, FCM credential, or Storage signing secret in Flutter or browser code.

## Authentication and storage

Supabase Auth provides phone OTP and email/password sessions. The Edge Functions require the resulting bearer token. Create a private Storage bucket named `kyc-documents` before using KYC upload functions; production policies must restrict KYC access to signed server/admin workflows.

## Phase 3 environment

Copy `.env.example` to a local, untracked environment file and set values through Supabase secrets for deployment. The repository intentionally contains no real credentials.
