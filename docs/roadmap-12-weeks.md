# CivilConnect 12-week delivery roadmap

## Milestones

| Week | Milestone | Dependencies | Exit gate |
|---|---|---|---|
| 1 | Architecture, business decisions, legal/tax questions | Product owner, legal/tax review | Phase 1 decisions recorded |
| 2 | Schema, RLS, state machines | Supabase projects | Migration reset and policy review pass |
| 3 | Auth, profiles, service catalog | Auth/Storage configuration | Phone/email flows and RLS tests pass |
| 4 | Discovery, GPS, availability, dispatch | PostGIS, maps/location | Eligibility and race tests pass |
| 5 | Customer/professional booking lifecycle | Realtime, FCM plan | End-to-end booking state flow pass |
| 6 | Quote, dispute and support operations | Policy/config decisions | Approval/dispute evidence workflow pass |
| 7 | Online payments and refunds | Razorpay sandbox approval | Signature/webhook/idempotency tests pass |
| 8 | Cash receivables, settlements and ledger | Finance policy | Double-entry and concurrency tests pass |
| 9 | Mobile hardening and notifications | FCM, crash reporting | Android/iOS release candidate builds |
| 10 | Admin dashboard and reports | Staff roles, APIs | KYC/booking/finance workflows usable |
| 11 | Load, security, recovery and reconciliation | Staging data/load tools | Launch gates and restore drill pass |
| 12 | Controlled pilot and launch decision | Operations/support staffing | Canary metrics and go/no-go review |

## Prioritization

### MVP

Auth, customer/professional profiles, controlled service catalog, GPS booking, manual/automatic matching, availability safeguards, arrival/start verification, itemized quote approval/dispute, online/cash payment, ledger, cash exposure, KYC review, support, ratings, notifications, RLS, audit and admin monitoring.

### V1

FCM retry/fallback, realtime live location, chat, masked calling, promotions/referrals, advanced reports, automated settlement scheduling, reconciliation dashboards, stronger fraud signals and multi-city configuration.

### V2

More sophisticated dispatch optimization, background-check provider integration, predictive staffing, richer route/battery optimization, automated tax/invoice integrations after legal approval, and marketplace payout expansion.

## Launch gates

- No critical security, ledger, payment or RLS failures.
- Provider sandbox and production fund flow approved.
- Tax/legal/privacy/cancellation policies reviewed.
- Support and SOS operating process staffed.
- Backups/restoration drill completed.
- p95 and crash/error targets measured in staging.
- Monitoring, alerting, reconciliation and rollback owners assigned.
- Canary booking, refund and settlement verified end-to-end.

## Major risks

Provider marketplace eligibility, Indian tax treatment, KYC/privacy operations, cash credit exposure, location fraud, dispatch supply density, support response quality, and cross-platform release configuration. Each risk requires an owner and a measurable mitigation before the relevant launch gate.
