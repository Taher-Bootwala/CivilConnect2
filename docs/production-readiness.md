# CivilConnect Phase 7 — Production readiness

## Environments

Use three isolated Supabase projects:

| Environment | Purpose | Data | Credentials |
|---|---|---|---|
| Development | Local feature work and seeded test data | Synthetic only | `.env.local`, local Supabase secrets |
| Staging | Release candidate and provider sandbox testing | Synthetic or anonymized | Staging Supabase secrets and Razorpay test mode |
| Production | Real customers and money | Production records | Managed secret store; no developer workstation credentials |

Promote the same migration commit through environments. Do not edit production tables manually. Apply migrations with the Supabase CLI after reviewing the generated plan.

## Required production secrets

Configure these only in Supabase/CI secret storage:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
RAZORPAY_KEY_ID
RAZORPAY_KEY_SECRET
RAZORPAY_WEBHOOK_SECRET
FCM_SERVER_CREDENTIALS_JSON
DISPATCH_WORKER_SECRET
RECONCILIATION_WORKER_SECRET
RAZORPAY_PAYOUTS_ENABLED=false
```

Set `RAZORPAY_PAYOUTS_ENABLED=true` only after Razorpay marketplace eligibility, professional onboarding, fund flow, provider fees, and operational reconciliation have been approved.

## Deployment sequence

1. Run Flutter analyzer/tests and build checks.
2. Run `npm ci`, `npx tsc --noEmit`, and `npm run build` in `admin-dashboard`.
3. Apply Supabase migrations to staging and run database smoke/integration tests.
4. Deploy Edge Functions to staging and configure webhook URLs with Razorpay test mode.
5. Exercise booking, quote, payment, duplicate webhook, refund, settlement and payout-disabled flows.
6. Obtain operations, finance, security, tax/legal and provider sign-off.
7. Apply the same migration revision to production.
8. Deploy functions and dashboard using the same revision.
9. Perform a canary booking with a controlled account; verify ledger, notifications and audit records.
10. Monitor error rate, latency, webhook backlog, reconciliation mismatches and crash reports.

Example commands after installing the Supabase CLI:

```bash
supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase db push
supabase functions deploy --no-verify-jwt razorpay-webhook
supabase functions deploy --no-verify-jwt dispatch-worker
supabase functions deploy --no-verify-jwt reconciliation-worker
supabase functions deploy admin-dashboard-metrics
supabase functions deploy admin-bookings
```

## CI/CD

`.github/workflows/ci.yml` runs Flutter format/analyze/test/APK build, admin TypeScript/build checks, secret-pattern checks, and RLS policy coverage checks. Production deployment should be a protected environment requiring review and should use short-lived or environment-scoped credentials.

## Monitoring and alerts

Capture structured logs with request ID, function name, actor role, entity ID and outcome. Never log tokens, passwords, KYC contents, card data, Razorpay secrets or unnecessary phone numbers.

Alert on:

- 5xx rate and p95 latency by Edge Function.
- Booking dispatch expiry/reassignment spikes.
- Arrival/start verification failures.
- Payment webhook signature failures and provider event backlog.
- Unbalanced journal attempts.
- Reconciliation mismatches and stale pending provider events.
- Cash exposure threshold breaches and settlement failures.
- KYC review backlog and account deletion SLA breaches.
- FCM delivery failures and unread critical notifications.
- Crash-free session and Android/iOS release health.

## Backup and restoration

- Enable Supabase automated backups and point-in-time recovery according to the selected plan.
- Export a periodic encrypted backup of schema metadata and operational configuration.
- Keep Storage objects and database records covered by a documented retention plan.
- Test restoration into an isolated project at least quarterly.
- Verify after restore: RLS, Auth integration, Storage private buckets, Realtime publication, Edge Function secrets, ledger balance reports, and webhook idempotency data.
- Record restore owner, start/end time, data-loss window and reconciliation result.

## Rollback

Application rollback: redeploy the previous immutable Flutter/admin/function artifacts.

Database rollback: use a forward corrective migration or an audited reversal. Never drop posted ledger history or overwrite approved pricing snapshots. Disable a feature with configuration/feature flags when a provider integration is unhealthy.

For payment incidents, stop new payment-order creation while preserving webhook ingestion and reconciliation. For payout incidents, set `RAZORPAY_PAYOUTS_ENABLED=false`; do not delete pending payout records.

## Security release gates

- RLS tests prove cross-customer, cross-professional and non-staff access is denied.
- Privileged role changes require server-side admin authorization.
- KYC files are private and signed access expires.
- Client amounts cannot alter quote/payment/settlement amounts.
- Provider webhook signatures and event IDs are verified/idempotent.
- Every posted journal balances and has a unique source reference.
- Secrets are absent from source, APK assets and browser bundles.
- Rate limits, input validation, audit logging and error redaction are enabled.

## Legal and operational review gates

Before real-money launch, obtain qualified Indian legal/tax review for GST invoice issuer/treatment, TDS, privacy/data retention, terms, professional agreements, cancellation/no-show policy, KYC retention and Razorpay marketplace fund flow. The application deliberately keeps these values configurable rather than asserting legal conclusions in code.
