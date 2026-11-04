# Phase 2 data dictionary

All timestamps are UTC `timestamptz`. All monetary values are integer paise (`bigint`) and use `INR` by default. The database never stores card data or Razorpay secrets.

| Area | Table | Important fields |
|---|---|---|
| Identity | `profiles` | Canonical Auth user; `primary_role`, `account_status`, verification timestamps. Privileged fields are trigger-protected. |
| Identity | `customer_profiles` | Customer-only preferences and default address reference. |
| Identity | `labor_profiles` | Professional onboarding, KYC status, online/availability state, rating aggregates, completed jobs, payout identifiers. |
| Identity | `labor_kyc` | Private document metadata and private Storage path; status, reviewer, rejection, and expiry. |
| Identity | `admin_roles` | Database-controlled staff role and permission metadata. Revocation is timestamped. |
| Catalog | `service_categories` / `services` | Public service catalog, descriptions, duration and estimate guidance. |
| Catalog | `service_pricing` | Effective-dated commission, fixed fee, tax, caps, and material/visiting treatment. Scope is global/category/service/professional. |
| Catalog | `service_price_guide_items` | Non-binding itemized price guidance and add-ons. |
| Availability | `labor_services` | Professional-to-service eligibility mapping and experience. |
| Availability | `labor_availability` / `labor_leaves` | Weekly local hours and timestamp-range leave exceptions. |
| Availability | `service_areas` | PostGIS center point and service radius. |
| Booking | `bookings` | Customer, service, selected/assigned professional, independent booking/payment/settlement states, appointment range, problem, snapshots. |
| Booking | `booking_locations` | GPS-derived service location and display address snapshot. Coordinates are authoritative; address text is not. |
| Booking | `booking_assignments` | Dispatch attempt, rank, response deadline, response/rejection/expiry. |
| Booking | `booking_status_history` | Append-only state transition history with actor and reason. |
| Booking | `labor_live_location` | Short-lived authorized professional location, accuracy, mock-location signal and active booking. |
| Booking | `work_sessions` | One verified active work session per professional. |
| Quote | `booking_amount_proposals` | Quote revision and immutable financial calculation fields after approval. |
| Quote | `quote_line_items` | Labor, materials, visiting, add-ons, discounts and tax lines. |
| Quote | `disputes` / `dispute_events` | Customer dispute, counter amount, escalation, resolution and event history. |
| Money | `payments` | Customer payment method, status, amount, idempotency key and provider identifier. |
| Money | `payment_provider_orders` / `payment_provider_events` | Razorpay order/event audit records. Events are unique by provider event ID. |
| Money | `refunds` | Full/partial refund request and provider status. |
| Money | `ledger_accounts` | Named accounting accounts, including professional subaccounts. |
| Money | `ledger_transactions` / `ledger_entries` | Append-only double-entry journals and debit/credit lines. |
| Money | `platform_receivables` | Outstanding commission/fixed-fee dues owed by a professional. This drives the initial ₹5,000 rule. |
| Money | `cash_settlements` | Professional deposits/settlements with idempotency and verification state. |
| Money | `professional_payouts` | Online earnings payout requests and provider state. |
| Money | `payment_reconciliations` | Provider-vs-ledger amount matching and resolution. |
| Money | `financial_adjustments` | Authorized, reasoned corrections linked to a ledger transaction. |
| Experience | `ratings` | One review per booking/reviewer, moderation state, tags and Bayesian input data. |
| Experience | `notifications` | Persisted inbox/push event; push delivery is not source of truth. |
| Experience | `chat_threads` / `chat_messages` | Booking-scoped in-app messaging without direct phone exposure. |
| Experience | `support_tickets` | Customer/professional support queue, priority, assignment and resolution. |
| Experience | `promo_codes` / `promotional_redemptions` | Configurable promotion eligibility and booking redemption. |
| Governance | `audit_logs` | Actor, action, entity, reason, before/after data and request metadata. |
| Governance | `app_config` | Effective-dated operational configuration such as lead time and cash threshold. |
| Governance | `consents` / `policy_versions` | Versioned privacy, terms, cancellation, payment and other policy records. |
| Governance | `account_deletion_requests` | Deletion workflow with retention-aware status. |
| Safety | `emergency_contacts` / `sos_events` | Emergency contact and operational SOS records. |

## Derived financial balances

- **Gross cash collected:** captured cash payment amounts for a professional’s bookings.
- **Cash earnings:** approved professional earnings on captured cash bookings.
- **Outstanding platform dues:** sum of `platform_receivables.outstanding_amount_paise`.
- **Online earnings:** approved professional earnings on captured online bookings.
- **Withdrawable balance:** payable ledger balance after holds, reserves, disputes, and completed payouts; the Phase 2 summary function exposes the base payable calculation and production payout policy must add the confirmed operational holds.
- **Pending payouts:** `professional_payouts` in `pending` or `processing` state.

These measures are intentionally separate. A professional collecting customer cash does not make the gross amount their income, and a platform receivable is not silently deducted from an undefined wallet.
