# CivilConnect Admin Dashboard

Separate responsive Next.js/Tailwind control room for authorized CivilConnect administrators.

## Run locally

```bash
npm install
copy .env.example .env.local
npm run dev
```

Open `http://localhost:3000`. Configure a Supabase URL and public key before signing in. Staff membership is read from `admin_roles`; the browser does not accept a client-supplied role.

## Screens

- Overview: operations metrics, booking pulse and control-room signals.
- Live bookings: dispatch, assignment, location privacy, booking/payment states.
- Professionals: onboarding, KYC status, coverage and ranking context.
- Customers: customer management and private support context.
- KYC review: restricted-document workflow and audited decisions.
- Disputes & support: quote/payment disputes and escalation context.
- Finance & ledger: posted journals, receivables, refunds, settlements and payouts.
- Services & pricing: effective-dated catalog and pricing controls.
- Reports: operational, financial and performance exports.
- Settings: policies, roles, notifications and environments.

## Security boundary

The dashboard is an operator interface, not a security boundary. Supabase Auth, RLS and server-side Edge Functions must authorize every read and write. Financial amounts are sourced from backend ledger state. The UI intentionally renders an empty authorized state when live endpoints are not configured rather than inventing operational or financial data.

The overview connects to the `admin-dashboard-metrics` and `admin-bookings` Edge Functions. These functions require an active `admin_roles` record and use service-role reads only after the staff check.
