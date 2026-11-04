# CivilConnect security and test model

## Protected assets

- Auth identities, phone/email verification and role assignments.
- Customer GPS snapshots, phone/contact data, chat and job media.
- Professional KYC documents and payout identifiers.
- Approved quote amounts, payment provider identifiers and ledger journals.
- Cash receivables, settlements, payouts and audit history.

## Trust boundaries

1. Flutter/mobile and browser clients are untrusted.
2. Supabase Auth establishes identity but not business authorization by itself.
3. RLS protects exposed rows.
4. Edge Functions and security-definer database functions perform privileged business actions.
5. Razorpay webhooks are untrusted until raw-body signature and provider event identity are verified.
6. Private Storage objects require signed, authorized access.

## Abuse cases and controls

| Abuse case | Control | Test evidence |
|---|---|---|
| Read another customer’s booking | RLS participant policy | RLS integration test |
| Professional reads location before acceptance | Booking-location policy and state check | Authorization test |
| User promotes self to admin | Protected role table and server-only role assignment | Privilege escalation test |
| Client changes quote/payment amount | Server-side pricing and frozen snapshot | Tamper test |
| Duplicate webhook credits money | Provider event uniqueness and journal reference | Idempotency test |
| Forged webhook | Raw-body HMAC verification | Signature-negative test |
| Duplicate cash collection | Idempotency key and professional transaction lock | Concurrency test |
| Payout exceeds earnings | Payable balance lock and pending-payout subtraction | Financial test |
| KYC URL leaks publicly | Private bucket and signed URL flow | Storage policy test |
| GPS spoofing proves arrival | Accuracy/geofence signals treated as fraud inputs, plus OTP | Verification test |
| Brute-force booking/payment endpoints | Edge rate limiting and idempotency | Load/abuse test |

## Minimum security test run

Run against an isolated Supabase project with synthetic users:

```text
customer_a cannot select customer_b bookings
professional_a cannot select professional_b KYC or private location
customer cannot insert admin_roles or alter profile role/status
unapproved professional cannot receive or accept a booking
client-supplied quote amount is ignored/rejected
duplicate provider event creates one payment and one journal
invalid webhook signature creates no financial state change
concurrent cash collections respect one exposure lock
unverified settlement leaves receivables unchanged
approved quote cannot be edited in place
posted journal rejects unequal debit/credit totals
```

Use redacted fixtures and destroy the project after the run. Do not use production KYC, payment or location data in tests.
