# Phase 4 financial test plan

`phase4_financial_invariants.sql` is a transactional smoke test for balanced and unbalanced journal posting. It rolls back its fixtures.

The integration suite should run these scenarios against an isolated Supabase project:

1. Two concurrent quote approvals cannot create two approved proposals.
2. Two duplicate Razorpay webhook deliveries create one payment and one journal.
3. A client callback without provider API/webhook confirmation cannot capture payment.
4. Two concurrent cash collections serialize on the professional exposure lock.
5. A settlement cannot reduce receivables until provider verification succeeds.
6. Partial settlements reduce receivables FIFO and preserve remaining balance.
7. Duplicate refunds and payout events do not create duplicate journals.
8. Payouts cannot exceed posted payable balance minus pending payouts.
9. Refund totals cannot exceed captured payment amount.
10. Every posted journal has equal positive debit and credit totals.

These tests require Supabase CLI/Docker or a dedicated PostgreSQL test project and are not executed in the current workspace because those tools are unavailable.
