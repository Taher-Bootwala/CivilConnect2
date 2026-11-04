# Phase 4 financial infrastructure

## Pricing flow

`submit-quote` accepts only itemized labor, material, visiting and add-on lines. PostgreSQL selects effective pricing using this precedence:

```text
professional override > service > category > global
```

The function stores a pricing snapshot and calculates, in paise:

```text
subtotal = labor + materials + visiting + add-ons
commission_basis = labor + add-ons
                  + materials when configured
                  + visiting when configured
commission = clamp(round(commission_basis × commission_rate_bps / 10000), min, max)
tax_base = configured taxable components + fixed platform fee
tax = round(tax_base × tax_rate_bps / 10000)
customer_payable = subtotal + fixed platform fee + tax
professional_earnings = subtotal - commission
```

The approved quote is immutable for future configuration changes. Materials pass through without commission by default; the effective pricing snapshot controls the actual historical behavior.

## Online payment

1. `prepare_online_payment` locks the approved quote and creates an idempotent pending payment.
2. `create-payment-order` sends only the server-calculated paise amount to Razorpay.
3. Flutter receives the provider order and opens Checkout.
4. `verify-payment` validates the client signature and then queries Razorpay’s authoritative payment API.
5. `razorpay-webhook` verifies the raw-body signature and processes duplicate events idempotently.
6. `capture_online_payment` posts a balanced journal and marks the booking paid.

A Flutter callback alone cannot post a successful payment.

## Cash settlement

`platform_receivables` is the source for outstanding platform dues. Cash collected by a professional, professional earnings, and platform dues remain separate. The default limit is 500,000 paise and is checked under a professional advisory transaction lock.

Verified settlement deposits reduce receivables FIFO and post a bank-to-professional-cash clearing journal. Failed, duplicate, partial, and delayed provider events remain explicit states.

## Refunds and payouts

- Refund requests are bounded by captured payment minus existing pending/processed refunds.
- Provider refund webhooks create a reversing journal; history is never overwritten.
- Payout requests are limited to posted professional payable balance less pending payouts.
- Razorpay marketplace payout activation remains feature-gated until provider eligibility, onboarding, and fund flow are confirmed. No payout secret or provider capability is assumed.

## Production controls

- Configure tax and commission values only through authorized effective-dated admin controls.
- Store Razorpay secrets in Supabase secrets, never in Flutter or browser code.
- Process provider webhooks from the raw request body and persist provider event IDs before processing.
- Run scheduled provider reconciliation in addition to immediate webhook handling.
- Review the Indian tax invoice, GST/TDS, refund and marketplace fund-flow behavior with qualified professionals before production activation.
