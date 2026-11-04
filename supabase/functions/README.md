# CivilConnect Edge Functions

## Functions delivered in Phase 3

| Function | Method | Responsibility |
|---|---|---|
| `profile` | GET/PATCH | Authenticated profile read and safe profile fields |
| `service-discovery` | GET | Active service catalog search |
| `nearby-professionals` | POST | PostGIS-backed eligible professional ranking |
| `create-booking` | POST | Server-time booking creation through a transactional RPC |
| `dispatch-booking` | POST | Automatic matching and assignment creation |
| `booking-action` | POST | Accept/reject/on-the-way/arrival/start/cancel actions |
| `professional-onboarding` | POST | Professional profile, services, area and availability |
| `kyc-upload-url` | POST | Private signed KYC upload URL |
| `kyc-submit` | POST | KYC metadata validation and submission |
| `dispatch-worker` | POST | Cron-authenticated expiry maintenance; not a user endpoint |
| `submit-quote` | POST | Backend pricing/commission/tax calculation and quote versioning |
| `create-payment-order` | POST | Server-priced Razorpay Checkout order |
| `verify-payment` | POST | Signature plus authoritative Razorpay API verification |
| `razorpay-webhook` | POST | Signed, idempotent payment/refund/payout events |
| `refund-request` | POST | Customer refund request after captured online payment |
| `create-settlement-order` | POST | Razorpay order for professional cash-dues settlement |
| `request-payout` | POST | Payable-balance-checked payout request |
| `financial-reconciliation` | POST | Staff reconciliation record |

## Required secrets

Configure environment-specific values through Supabase secrets or the deployment system:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
```

Financial provider, FCM, maps, and email/SMS secrets must remain server-side. Phase 4 requires `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, and an explicit `RAZORPAY_PAYOUTS_ENABLED` flag. Payouts remain disabled until the approved marketplace fund flow is confirmed.

## Local/deployment notes

The repository currently does not include the Supabase CLI. After installing it:

```bash
supabase functions serve create-booking --env-file .env.local
supabase functions deploy create-booking
supabase secrets set --env-file .env.production
```

Use separate Supabase projects for development, staging and production. The KYC function expects a private Storage bucket named `kyc-documents`; production bucket policies must allow only service-role signed operations and approved admin access.

## Authentication

Phone OTP, email/password, recovery, and method linking use Supabase Auth. The client sends the resulting bearer token to these functions. The functions resolve the token through `auth.getUser()` and never accept a role from request JSON.

## Error contract

```json
{
  "error": { "code": "INVALID_FIELD", "message": "...", "details": null },
  "request_id": "..."
}
```

Mutating calls should send `Idempotency-Key`. The database owns idempotency for booking creation and cash/financial operations; the client must retry with the same key after a network timeout.
