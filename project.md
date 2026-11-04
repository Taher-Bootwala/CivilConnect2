# MASTER PROMPT: Production-Grade On-Demand Home Services Marketplace

## ROLE AND OBJECTIVE

Act as a senior software architect, Flutter engineer, Supabase/PostgreSQL database architect, payment systems engineer, and product security specialist.

Design and implement a production-grade, Uber-style on-demand home services marketplace for India. Customers must be able to book verified service professionals such as plumbers, electricians, carpenters, painters, cleaners, AC repair technicians, and other local workers.

The application must be suitable for real-world deployment, not merely a prototype or UI demonstration.

Deliver the architecture, database schema, backend functions, Flutter applications, payment and settlement systems, admin dashboard, testing strategy, and deployment documentation in a structured, step-by-step manner.

**Important working rules:**
- Follow the confirmed business decisions below.
- Preserve every distinct requirement in this specification.
- Do not implement the same feature twice under different names.
- Do not silently invent business rules or make major architectural changes.
- Identify ambiguities, financial risks, security concerns, and unresolved decisions before implementing the affected functionality.
- Ask me to confirm genuinely important unresolved business decisions.
- Never expose secrets, trust client-calculated financial amounts, or allow clients to bypass backend authorization.
- Build functional, integrated features rather than mock screens or placeholder implementations.
- Deliver the work module by module and wait for my explicit **CONTINUE** before proceeding to the next major deliverable.

---

## 1. CONFIRMED PRODUCT AND BUSINESS DECISIONS

Treat the following as the authoritative requirements.

| Decision | Confirmed choice |
|---|---|
| Mobile platform | Flutter for Android and iOS |
| Backend and database | Supabase PostgreSQL, Auth, Realtime, Storage, and Edge Functions |
| Notifications | Firebase Cloud Messaging (FCM) |
| Online payments | Razorpay |
| Authentication | Phone OTP and email/password |
| Booking and matching | Customer-selected professional and automatic matching |
| Pricing | Laborer-generated final quote after completing the work |
| Platform revenue | Percentage commission plus fixed platform fee |
| Cash settlement | Professionals collect cash from customers and settle amounts owed to the platform |
| Cash exposure threshold | ₹5,000, configurable by an authorized administrator |
| Minimum advance booking | 30 minutes from the server-authoritative current time |
| Customer payment timing | No upfront booking charge; payment follows work completion and customer approval |

Use integer paise or an appropriately precise decimal representation for all monetary calculations. Never use floating-point arithmetic for money.

All financial rates, limits, penalties, service estimates, and platform fees must be configurable through authorized administrative controls.

Do not silently replace Supabase with a separate NestJS or Express backend. Use Supabase as the primary backend. Introduce additional infrastructure only when justified by a specific requirement.

## 2. APPLICATIONS AND USER ROLES

Build three role-based interfaces.

### A. Customer mobile application

Customers must be able to:
- Register, log in, manage their profiles, and verify their phone numbers.
- Browse and search service categories.
- Describe a problem using text, photos, and optional voice notes.
- Share their current GPS location and view its reverse-geocoded address.
- Browse eligible professionals ranked from highest to lowest rating.
- Select a specific professional or use automatic matching.
- Book immediately or schedule a future appointment.
- Track bookings, professional arrival, work progress, and payment status.
- Approve final quotes, raise disputes, pay online or in cash, and rate completed jobs.
- View booking history, invoices, receipts, saved professionals, and support tickets.
- Access cancellation policies, promotions, notifications, and account settings.

### B. Service professional mobile application

Professionals must be able to:
- Register, complete onboarding, submit KYC documents, and select their services.
- Set their service area, travel radius, working hours, weekly availability, and holidays.
- Toggle their online/offline status.
- Receive booking requests and accept or reject them within a configurable countdown.
- View customer location and contact information only after accepting a booking.
- Navigate to the customer, verify arrival, and start work securely.
- Submit final quotes with an itemized breakdown and optional photographs.
- Confirm cash collection, review earnings, settle platform dues, and request eligible payouts.
- View upcoming jobs, ongoing work, completed jobs, transaction history, ratings, and penalties.
- Receive settlement warnings, KYC updates, booking notifications, and account restrictions.

### C. Admin web dashboard

Build a separate responsive web dashboard using React, Next.js, and Tailwind CSS.

Administrators must be able to:
- Manage customers, professionals, administrators, and service categories.
- Approve, reject, or suspend professional accounts and review KYC records.
- Manage pricing, service estimates, commissions, fixed fees, taxes, and cash limits.
- Monitor bookings, cancellations, assignments, live work, and customer complaints.
- Inspect the financial ledger, collections, settlements, refunds, and payouts.
- Resolve quote disputes, payment disputes, and support tickets.
- Manage promotional campaigns, banners, referral programs, and configurable policies.
- Review ratings, suspicious activities, audit logs, and financial reconciliation reports.
- Apply authorized financial adjustments with mandatory reasons and audit records.
- Generate operational, financial, and performance reports.

Enforce role-based access control and least-privilege permissions throughout all three interfaces.

---

## 3. RECOMMENDED TECHNICAL ARCHITECTURE

Use the following primary stack.

### Mobile
- Flutter and Dart.
- Riverpod for state management.
- GoRouter for navigation and route guards.
- Supabase Flutter SDK for authentication, database access, storage, and Realtime.
- Firebase Cloud Messaging for push notifications.
- Google Maps Platform and geolocator for mapping, GPS, and navigation.
- flutter_secure_storage for sensitive local tokens or credentials where appropriate.
- Hive or Isar for carefully selected local caching.
- Razorpay Flutter SDK for checkout.

### Backend
- Supabase Auth for identity and authentication.
- PostgreSQL for transactional data.
- PostGIS for proximity searches and geospatial queries.
- Supabase Edge Functions for privileged business operations, Razorpay integration, webhooks, settlement, and administrative actions.
- Supabase Realtime for booking status synchronization and relevant live updates.
- Supabase Storage for suitable application files, with private buckets and signed access where required.
- FCM for push notifications.

Use scheduled Supabase jobs or another justified background-job mechanism for expiry handling, retries, reconciliation, reminders, and scheduled settlements. If Redis or an external queue is necessary, explain why before introducing it.

### Security and infrastructure
- Separate development, staging, and production environments.
- Store secrets in environment-specific secret management.
- Use database migrations, automated backups, structured logs, and monitoring.
- Apply rate limiting, request validation, idempotency, and audit logging.
- Use CI/CD with GitHub Actions.
- Add crash reporting and application performance monitoring.
- Document environment configuration, release procedures, backup restoration, and rollback.

Keep service-role credentials and Razorpay secret keys exclusively on trusted server-side infrastructure.

---

## 4. AUTHENTICATION, ONBOARDING, AND SECURITY

Support both phone OTP authentication and email/password authentication.

Requirements:
- Allow secure account recovery and password reset.
- Link authentication methods to a single user profile only after verifying ownership of both methods.
- Prevent duplicate accounts, unauthorized account linking, and privilege escalation.
- Maintain canonical user records and separate customer and professional profiles.
- Use database-controlled roles and server-side authorization.
- Require phone verification before booking, subject to configurable policy.
- Require professional KYC approval before allowing professionals to receive jobs.
- Collect professional name, photograph, services, experience, operating area, and relevant bank/UPI details.
- Support identity-document uploads and verification status tracking.
- Keep sensitive KYC information private and restrict access to authorized administrators.
- Provide consent records, account deletion, privacy controls, and appropriate data-retention policies.

Use Supabase Auth sessions and secure token handling. Do not assume that a client-side role, hidden button, or route guard is a security boundary.

For exposed tables, enable Row Level Security (RLS) with policies that enforce actual record ownership and role permissions.

---

## 5. CUSTOMER BOOKING WORKFLOW

Implement the following complete workflow.

### Step 1: Discover a service
Display searchable service categories such as plumbing, electrical repairs, cleaning, carpentry, painting, and AC maintenance.

Each service should support:
- Description and category.
- Configurable estimate range.
- Visiting charge policy.
- Typical service duration.
- Relevant price-guide items and optional add-ons.
- Commission configuration and applicable platform fee.

### Step 2: Describe the problem
Allow the customer to submit a description, optional photographs, and optional voice notes.

Validate file types, sizes, access permissions, and uploads.

### Step 3: Determine location
The booking must use the customer's device GPS coordinates as the source of the service location. Do not allow a manually typed address to replace the required GPS coordinates.

Reverse-geocode the coordinates for display and allow a flat number, landmark, or additional directions.

Handle denied permissions, disabled GPS, inaccurate location, and poor connectivity gracefully.

Save the relevant booking coordinates and address snapshot. Do not continuously expose a customer's location unnecessarily.

### Step 4: Find eligible professionals
Search professionals who:
- Offer the selected service.
- Have approved and active accounts.
- Are online and within their service radius.
- Are available for the requested time slot.
- Are not suspended, restricted, or occupied by conflicting work.
- Meet applicable eligibility and safety requirements.

Sort results using a Bayesian or weighted rating that accounts for both rating and review count.

Use distance and completed-job count as tie-breakers. Account for recent performance and verified reviews where appropriate.

Display professional photographs, names, ratings, review counts, experience, completed jobs, distance, visiting charges, and relevant price guidance.

### Step 5: Select or automatically match
Provide two distinct booking modes:

1. **Choose a professional:** The customer selects a specific eligible professional.
2. **Pick for me:** The backend automatically dispatches the request to eligible professionals.

For automatic matching, implement configurable dispatch strategies such as sequential dispatch to the highest-ranked eligible professional or broadcasting to a limited group of suitable professionals.

Use the strategy that best balances rating, proximity, availability, and response time. Prevent multiple professionals from winning the same booking.

Record dispatch attempts, rejection reasons, expiry events, and reassignment history.

### Step 6: Select the appointment
Support:
- Book now (ASAP).
- Schedule later.
- Date and time selection.
- Service-duration estimates and travel buffers.
- Professional working hours, holidays, and availability.
- A minimum booking lead time of 30 minutes.
- A configurable maximum advance-booking window.

Use server time, not the device clock, for booking eligibility.

### Step 7: Confirm the request
Display the service, professional or matching method, GPS-derived address, appointment time, visiting-charge policy, price guidance, cancellation terms, and applicable disclosed fees.

**Do not collect or pre-authorize a booking fee when the request is submitted.**

Create the booking and initiate dispatch transactionally. If a professional rejects or ignores the request, expire or reassign it according to the configured dispatch policy.

### Step 8: Track the booking
Synchronize booking status between the customer, professional, and admin dashboard.

Provide live location tracking after the professional marks themselves as on the way and obtains the required location permissions.

Use battery-conscious location updates and restrict access to authorized participants.

---

## 6. PROFESSIONAL WORKFLOW AND JOB VERIFICATION

Implement a strict, backend-controlled workflow.

1. Receive a booking request through push notifications and the in-app request screen.
2. Show service details, appointment time, and approximate location.
3. Require acceptance or rejection within a configurable timeout, such as two minutes.
4. Reveal the exact customer location and phone number only after acceptance.
5. Provide navigation to the customer's location.
6. Allow the professional to mark themselves as on the way.
7. Verify arrival using GPS and configurable geofencing.
8. Require a customer-issued start OTP and a swipe-to-start action before beginning work.
9. Lock the professional's availability while work is in progress.
10. Allow the professional to submit a final quote and optional before/after photographs.
11. Send the quote to the customer for explicit approval or dispute.
12. Collect payment only after the applicable quote and charges are approved.
13. Update financial records only after the relevant payment or cash-collection event is verified.
14. Prompt for ratings after successful completion of the payment and booking workflow.

Use geofencing, server timestamps, reasonable location-accuracy checks, and mock-location detection where supported. Treat location checks as fraud signals rather than infallible proof.

The customer must never see the professional's direct phone number. Use in-app chat or masked calling where supported.

The professional must not be able to start multiple active jobs. Prevent double-booking and handle overruns by adjusting availability and notifying affected parties.

Distinguish work completion from financial completion. A submitted quote, completed job, successful customer payment, and settled platform commission are separate events.

---

## 7. FINAL QUOTE, CUSTOMER APPROVAL, AND DISPUTES

This workflow is mandatory because pricing is based on the professional's final quote.

### Quote submission
When work is finished, the professional submits:
- Labor charges.
- Material costs.
- Visiting charges, where applicable.
- Additional approved items.
- Optional before/after photographs.
- A reason for charges outside the configured estimate range.

Calculate the final payable amount and platform fees on the backend.

### Customer approval
The customer receives a screen displaying the complete quote, itemized charges, relevant estimate range, applicable taxes, platform fees, and photographs.

Provide two primary actions: **Approve quote** and **Dispute quote**.

No cash payment, online payment, rating, or final financial settlement may proceed before the applicable amount is approved or resolved through the dispute process.

### Dispute resolution
When the customer disputes a quote:
- Require a reason and optionally allow a proposed counter-amount.
- Notify the professional.
- Allow the professional to accept the counter-amount, revise the quote, or maintain their position.
- Limit revisions, for example to two revisions, through configurable policy.
- Automatically escalate unresolved disputes after a configurable period, initially 15 minutes.
- Create a support ticket containing quote versions, photographs, chat history, timestamps, price guidance, and relevant arrival or work-verification events.
- Allow an authorized administrator to determine the final amount with a mandatory written reason.
- Notify both parties and record the decision in the audit log.

Do not auto-approve quotes when customers fail to respond. Send reminders and escalate after a configurable response period.

Once a quote is approved, freeze its amount and applicable pricing snapshot. Any correction must be performed through an authorized, audited adjustment.

For quotes exceeding a configurable threshold above the estimate, require supporting evidence and flag the booking for administrative review.

Keep disputed financial obligations in the appropriate pending state until resolution. A dispute must not automatically block unrelated customer bookings.

---

## 8. PRICING AND PLATFORM REVENUE MODEL

Implement the confirmed revenue model: **percentage commission plus a fixed platform fee**.

### Pricing configuration
Support:
- Commission configured per service.
- Percentage-based commission.
- Fixed platform fee.
- Optional minimum and maximum commission caps.
- Optional service-category and global defaults.
- Optional professional-specific commission overrides.
- Effective-from dates for configuration changes.
- Tax rules and configurable material-cost treatment.

Use a documented precedence hierarchy: professional-specific override, service, category, and global default.

### Initial proposed formula

Let:
- S = approved service quote.
- C = applicable percentage commission.
- F = fixed platform fee.
- T = applicable taxes.

Calculate the commission using the approved service-quote basis and the configured caps.

Unless explicitly configured otherwise:
- The customer pays the approved service quote plus the disclosed fixed platform fee and applicable taxes.
- The professional's earnings are the service quote minus the applicable commission.
- The platform's gross revenue comprises the commission and fixed platform fee.
- Material costs pass through without commission unless an authorized configuration specifies otherwise.

The fixed fee is initially charged to the customer, while the percentage commission is charged to the professional. Display all applicable charges before payment approval.

Apply commission to visiting charges when configured. Handle material costs and tax allocation according to the selected policy and applicable law.

### Immutable pricing snapshots
At the time the final quote is approved, snapshot:
- Approved service amount.
- Commission type and rate.
- Commission amount.
- Fixed platform fee.
- Applicable taxes.
- Material-cost treatment.
- Professional earnings.
- Customer payable amount.
- Pricing configuration version.

Future changes to pricing configuration must never modify historical bookings, posted ledger entries, or previously approved charges.

---

## 9. CASH COLLECTION AND ₹5,000 SETTLEMENT RULE

Implement a complete, auditable financial system.

Do not confuse:
1. Gross cash physically collected by the professional.
2. The professional's earned income.
3. Outstanding commission and platform fees owed to the platform.
4. Online earnings payable to the professional.
5. Verified deposits and settlements.
6. Amounts eligible for withdrawal.

Track these balances separately.

### Cash collection
For a cash booking:
- The customer approves the quote and chooses cash.
- The professional collects the disclosed payable amount.
- The professional confirms receipt, with customer confirmation where appropriate.
- The backend records the collection idempotently.
- The ledger records professional earnings and outstanding platform receivables.
- The professional's dashboard updates only after the appropriate transaction is posted.

The professional collects the customer's cash but must remit the applicable platform commission and fixed fee to the platform under the approved settlement policy.

### Cash exposure limit
Use ₹5,000 as the default configurable limit.

For the initial accounting model, apply this limit to the professional's **outstanding platform obligations from cash bookings**, including unpaid commission and fixed platform fees. Separately track gross physical cash collected.

If the intended business policy is to limit all physical cash held by a professional instead, implement that as a separate configurable exposure limit. Do not treat these two measures as interchangeable.

When the professional reaches 80% of the applicable threshold, send a warning notification with a settlement action.

When a transaction would exceed the approved limit:
- Atomically evaluate the professional's outstanding obligation.
- Prevent further restricted cash exposure.
- Apply the configured restriction or soft-lock policy.
- Allow eligible online bookings if permitted by the approved business rules.
- Offer a secure deposit or settlement workflow.
- Restore eligibility only after the required settlement has been verified.

Do not automatically deduct money from an undefined wallet balance. Any deduction from payable professional earnings must be supported by an approved policy, correct accounting entries, and an auditable transaction.

Handle concurrent collections, overpayments, refunds, disputed jobs, failed deposits, duplicate webhook events, and partial settlements.

Run scheduled reconciliation in addition to immediate transaction-time checks.

### Professional financial dashboard
Display:
- Cash earnings.
- Online earnings.
- Total earnings.
- Gross cash collected and outstanding cash exposure.
- Outstanding platform dues.
- Wallet or payable balance.
- Withdrawable balance.
- Pending payouts.
- Settlement history.
- Deposit warnings and account restrictions.

Define every balance precisely. Do not calculate earnings by simply adding incompatible cash, revenue, and payable figures.

---

## 10. DOUBLE-ENTRY LEDGER AND ACCOUNTING

The financial ledger must be the authoritative source for financial reporting.

Implement journal transactions with balanced debit and credit entries.

At minimum, model:
- Customer payment receipts.
- Professional earnings payable.
- Platform commission revenue.
- Fixed platform fee revenue.
- Tax liabilities.
- Cash collected by professionals.
- Platform receivables from professionals.
- Payment gateway fees.
- Refunds and reversals.
- Deposits and verified settlements.
- Payouts and payout failures.
- Adjustments and disputed amounts.

Every journal transaction must include a unique reference, currency, timestamp, source booking or payment, transaction type, and audit metadata.

Every posted journal must satisfy:

Total debits = Total credits.

Requirements:
- Use append-only posted entries.
- Correct errors through reversals and adjustment entries rather than overwriting history.
- Enforce idempotency using unique transaction references.
- Use database transactions and row-level locking for concurrent financial operations.
- Separate pending, posted, settled, reversed, and failed states.
- Reconcile ledger balances with payment provider records and payout records.
- Prevent duplicate credits from retries or duplicate webhooks.
- Preserve complete financial history after cancellation or refund.

Keep booking status, payment status, and settlement status as separate state machines.

---

## 11. RAZORPAY PAYMENT INTEGRATION

Implement Razorpay through trusted server-side functions.

### Online payment flow
1. The customer approves the final payable amount.
2. The backend validates the booking, amount, fees, and payment eligibility.
3. A server-side function creates a Razorpay order using the amount in paise.
4. Flutter launches Razorpay Checkout using the server-created order ID and public key.
5. The client submits the resulting payment identifiers and signature to the backend.
6. The backend verifies the signature using the stored order ID and secret.
7. Signed webhooks and authoritative provider status confirm the payment.
8. The backend posts the appropriate ledger entries and updates the payment record.
9. The booking and financial dashboard are updated from verified backend state.

Never trust the Flutter client to determine the final amount or confirm a successful payment.

### Required payment capabilities
- UPI.
- Cards.
- Net banking.
- Supported wallets.
- Payment failure handling.
- Full and partial refunds where supported.
- Cash-settlement deposits.
- Professional payouts through an eligible Razorpay marketplace or payout arrangement.
- Payment status recovery and reconciliation.

### Webhook requirements
Handle relevant events such as:
- Payment captured or failed.
- Order paid.
- Refund processed.
- Payout initiated, processed, or failed.
- Relevant transfer events when using a supported marketplace arrangement.

Verify webhook signatures against the raw request body using the appropriate secret. Persist processed event identifiers and make handlers idempotent.

A client callback alone must never mark a payment as successful.

### Marketplace payouts
Evaluate Razorpay Route or another eligible supported arrangement for professional payouts and transfers. Confirm the platform's account eligibility, onboarding requirements, actual fund flow, and provider capabilities before enabling production transactions.

Do not assume that standard checkout automatically splits payments.

Keep card data out of the application's database. Store provider identifiers, payment status, and necessary audit information only.

---

## 12. AVAILABILITY, SCHEDULING, AND CONCURRENCY

Implement robust booking and scheduling controls.

Requirements:
- Model scheduled bookings using timestamp ranges.
- Prevent overlapping confirmed appointments.
- Use PostgreSQL range types and exclusion constraints where appropriate.
- Use a transaction to reserve a slot, accept a booking, and record the state transition.
- Enforce one active work session per professional.
- Consider service duration, travel time, buffer time, working hours, leave, and existing reservations.
- Lock professional availability during active work.
- Handle overruns without silently deleting or invalidating existing bookings.
- Notify affected customers when schedules must be adjusted.
- Release reservations correctly on cancellation, rejection, or expiry.
- Use server-side locking and transactional safeguards rather than relying solely on Redis or client-side checks.

Add indexes for service searches, professional IDs, customer IDs, booking statuses, scheduled time ranges, and payment provider identifiers.

Use PostGIS indexes for nearby-professional queries.

Test race conditions involving two customers booking the same professional, simultaneous acceptance of an automatically dispatched job, and simultaneous cash transactions.

---

## 13. BOOKING STATE MACHINE

Implement explicit state transitions enforced by backend functions and database permissions.

Use a state machine that supports the following logical flow:

REQUESTED → ACCEPTED → ON_THE_WAY → ARRIVED → IN_PROGRESS → WORK_DONE → AMOUNT_PENDING_APPROVAL → APPROVED or DISPUTED → PAYMENT_PENDING → PAID → CLOSED → RATED.

Support additional states and branches for:
- Rejected requests.
- Expired requests.
- Automatic reassignment.
- Customer or professional cancellation.
- No-shows.
- Quote revisions.
- Dispute escalation and resolution.
- Failed payments.
- Cash collection confirmation.
- Refund pending and refunded.
- Settlement pending and settled.

Keep payment and settlement states separate from booking status.

For every transition, record the previous state, next state, actor, timestamp, reason, and relevant metadata.

Reject unauthorized or invalid transitions. Provide a state transition diagram and tests for all permitted and forbidden transitions.

---

## 14. CANCELLATIONS, NO-SHOWS, AND PENALTIES

Implement configurable policies for customer cancellation, professional cancellation, late arrival, and no-shows.

Initial proposed policy:
- No upfront booking fee or pre-authorization.
- Customer cancellation is free until the professional marks themselves as on the way.
- Later cancellation may create a configurable penalty, initially in the ₹50–₹100 range.
- If the professional arrives and the customer is unavailable after a configurable waiting period, the system can record an applicable visiting-charge obligation.
- A no-show must be supported by arrival verification, timestamps, and the relevant contact attempts.
- Customer penalties and dues must be disclosed and recorded before enforcement.
- A configurable strike system can temporarily restrict repeat offenders.
- Repeated professional cancellations or no-shows may lead to penalties, ranking changes, or suspension according to documented policy.
- Professionals must receive fair compensation for verified customer no-shows under the configured rules.

Because there is no upfront payment, any cancellation fee or no-show charge must be represented as a due rather than falsely recorded as collected revenue.

Prevent customers with restricted outstanding dues from making new bookings only under a clearly disclosed, authorized policy.

All penalties, grace periods, and strike thresholds must be configurable. Do not silently charge, deduct, or suspend users outside the approved policy.

---

## 15. NOTIFICATIONS, REAL-TIME EVENTS, AND CHAT

Use Supabase Realtime for appropriate application state updates and FCM for push notifications.

Support notifications for:
- Booking requests and responses.
- Request expiration and reassignment.
- Appointment reminders.
- Professional departure and arrival.
- Work start and completion.
- Quote approval and dispute events.
- Payment requests and confirmed receipts.
- Cancellation and no-show events.
- Settlement warnings and deposits.
- KYC approval or rejection.
- Payout status.
- Ratings and support updates.

Persist notification records in the database and maintain an in-app inbox.

Push notifications must not be the source of truth. After reconnecting or restarting the application, clients must retrieve the current authorized state from the backend.

Implement optional in-app chat and masked calling while protecting personal contact details.

For critical notifications, support retries and an appropriate fallback mechanism when configured.

---

## 16. RATINGS, SAFETY, AND FRAUD PREVENTION

Implement:
- Customer ratings of professionals after eligible completed and paid bookings.
- Professional ratings of customers.
- One eligible review per booking.
- Rating tags and optional written comments.
- Bayesian rating calculations for ranking.
- Administrative moderation and review removal with audit history.
- Configurable ranking penalties or restrictions for repeated poor performance.
- SOS functionality with emergency contacts and support-team notification.
- Verified-professional and background-check status indicators.
- Start-work OTP and appropriate completion verification.
- Geofence and suspicious-location checks.
- In-app messaging and masked calls to reduce off-platform diversion.
- Detection of suspicious cancellations, fake reviews, duplicate bookings, and payment anomalies.

Do not present an identity check or GPS validation as an absolute guarantee of safety. Provide clear limitations and an operational support process.

---

## 17. DATABASE DESIGN AND REQUIRED TABLES

Provide a complete PostgreSQL schema with migrations, foreign keys, constraints, indexes, RLS policies, and supporting functions.

Include at least the following entities:

### Identity and onboarding
- users / profiles.
- customer_profiles.
- labor_profiles.
- labor_kyc.
- administrator profiles and role assignments.
- device_tokens.
- professional service mappings.

### Services and availability
- service_categories.
- services.
- service_pricing and commission configuration.
- labor_services.
- labor_availability.
- labor_leaves.
- service price-guide items.
- service-area and location records.

### Booking operations
- bookings.
- booking_status_history.
- booking_assignments or dispatch attempts.
- booking_locations.
- labor_live_location.
- work_sessions.
- booking_amount_proposals.
- booking verification records.
- cancellation and penalty records.

### Financial records
- payments.
- payment provider orders and events.
- refunds.
- ledger_accounts.
- ledger_transactions or journal headers.
- ledger_entries or journal lines.
- wallets or derived balance views.
- cash_settlements.
- professional payouts.
- platform receivables.
- payment and payout reconciliation records.
- financial adjustments.

### Customer experience and support
- ratings.
- notifications.
- chat_messages.
- disputes.
- dispute_events.
- support_tickets.
- promo_codes.
- promotional redemptions.
- saved professionals and addresses where applicable.

### Administration and compliance
- admin_users or role assignments.
- audit_logs.
- app_config.
- consent records.
- account deletion requests.
- policy and pricing version history.

Avoid duplicating identity information unnecessarily. Use canonical user IDs and enforce appropriate one-to-one and one-to-many relationships.

Provide:
1. An ER diagram.
2. Full SQL migrations.
3. Relevant PostgreSQL enums and constraints.
4. RLS policies for all exposed tables.
5. PostGIS and scheduling indexes.
6. Transactional database functions for critical operations.
7. Seed data for development and testing.
8. A data dictionary explaining important fields.
9. An explanation of how financial balances are derived and reconciled.

Do not place sensitive operations exclusively in client-side code.

---

## 18. API AND EDGE FUNCTION DESIGN

Create a documented, versioned API, using `/v1` in route naming where appropriate.

Implement authenticated, validated backend operations for:

### Authentication and onboarding
- Phone OTP and account authentication.
- Profile management.
- Professional registration and KYC submission.
- KYC approval and rejection.

### Customer and professional operations
- Service discovery.
- Nearby-professional search.
- Availability lookup.
- Booking creation.
- Booking acceptance and rejection.
- Automatic dispatch and reassignment.
- Arrival and work verification.
- Quote submission and approval.
- Dispute creation and resolution.
- Cancellation and no-show processing.
- Rating submission.
- Professional earnings and transaction history.

### Payments and settlement
- Payment-order creation.
- Payment verification.
- Razorpay webhooks.
- Refund requests.
- Cash collection confirmation.
- Settlement creation and verification.
- Professional payout initiation.
- Reconciliation and financial adjustments.

### Administration
- User and professional management.
- Service and pricing configuration.
- Booking monitoring.
- Commission and cash-limit configuration.
- Dispute resolution.
- Financial ledger inspection.
- Refunds, settlements, and payout management.
- Audit logs and reports.

Provide an OpenAPI specification or equivalent API documentation, standard error responses, pagination, input validation, idempotency headers, and authorization requirements.

Use transactional operations for booking acceptance, payment posting, quote approval, and financial settlement.

Document relevant Realtime events, including booking requests, acceptance, location changes, work start, quote submission, payment completion, and settlement updates.

---

## 19. INDIA-SPECIFIC COMPLIANCE

Design the application with applicable Indian legal and regulatory requirements in mind.

Include:
- Privacy policy and terms of service.
- Appropriate consent and personal-data handling under applicable data-protection law.
- Professional agreements and customer cancellation disclosures.
- GST treatment and invoice requirements where applicable.
- TDS or other tax handling where legally applicable.
- Payment-provider and marketplace compliance requirements.
- Account deletion and data-retention workflows.
- Secure handling of identity documents.
- Background-location disclosures and mobile-store permission requirements.
- Clear refund, dispute, and customer-support policies.

Do not invent legal conclusions or hardcode tax rates without verification. Identify the requirements that need review by a qualified Indian legal or tax professional.

---

## 20. PERFORMANCE, SECURITY, AND RELIABILITY

Design for an initial target of 100,000 registered users, with architecture that can scale as actual usage grows.

Initial engineering targets:
- p95 API response time below 300 ms for suitable non-heavy endpoints under defined test conditions.
- 99.9% service availability as an operational objective, not an unsupported guarantee.
- Crash-free mobile sessions above 99.5%.
- Battery-conscious location tracking.
- Secure storage and transport of sensitive information.
- Reliable recovery from network interruptions and app restarts.

Implement:
- RLS and server-side authorization.
- Input validation and output sanitization.
- Rate limiting and abuse prevention.
- Secure secret management.
- Idempotent financial operations.
- Webhook verification.
- Database transactions and concurrency controls.
- Structured logs, monitoring, alerts, and audit trails.
- Backup and restoration procedures.
- Appropriate mobile security controls, including certificate pinning where justified and safely managed.

Never log passwords, access tokens, payment secrets, or unnecessary sensitive personal information.

---

## 21. TESTING AND ACCEPTANCE CRITERIA

Provide unit, integration, security, concurrency, and end-to-end tests.

At minimum, verify that:

1. Customers cannot access another customer's private bookings.
2. Professionals cannot access unauthorized customer information.
3. Users cannot promote themselves to privileged roles.
4. Unapproved professionals cannot receive jobs.
5. Manual selection and automatic matching both work.
6. A professional cannot accept conflicting bookings.
7. A professional cannot start multiple active jobs.
8. The 30-minute lead time is enforced using server time.
9. Location and OTP requirements are enforced.
10. A professional cannot silently change an approved quote.
11. A customer cannot be charged without the required approval.
12. Duplicate Razorpay webhooks cannot duplicate financial entries.
13. Client-side callbacks alone cannot mark payments successful.
14. Cash collections and settlements remain correct under concurrency.
15. The ₹5,000 limit is enforced against the configured financial measure.
16. Double-entry journals balance.
17. Failed payments, refunds, and reversals preserve financial history.
18. Deposits reduce outstanding obligations only after verification.
19. Payouts cannot exceed the eligible payable balance.
20. Disputes correctly suspend the affected payment flow.
21. Notifications recover after app restart or network failure.
22. RLS policies prevent unauthorized reads and writes.
23. Earnings dashboards reconcile with ledger transactions.
24. Cancellation penalties and no-show fees follow the approved policy.
25. Android and iOS builds pass relevant integration tests.

Include edge cases for concurrent requests, duplicate retries, expired assignments, failed uploads, incomplete payments, professional overruns, disputed cash collections, overpayments, and delayed webhooks.

---

## 22. IMPLEMENTATION ORDER AND REQUIRED DELIVERABLES

Deliver the project in the following sequence.

**Phase 1 — Architecture and decisions**
- System architecture diagram.
- Technology choices and justification.
- Component responsibilities and data flows.
- Risk register.
- Assumptions and unresolved business decisions.

**Phase 2 — Database foundation**
- ER diagram.
- Full SQL migrations and constraints.
- RLS policies.
- Indexes and database functions.
- Booking, payment, and settlement state machines.

**Phase 3 — Backend core**
- Supabase Edge Functions and supporting modules.
- Authentication and onboarding.
- Service discovery and availability.
- Booking creation, assignment, and lifecycle.
- Realtime event design.
- API documentation.

**Phase 4 — Financial infrastructure**
- Pricing and commission engine.
- Double-entry ledger.
- Razorpay orders, verification, and webhooks.
- Cash collection and settlement.
- Refunds, payout integration, and reconciliation.
- Financial unit and concurrency tests.

**Phase 5 — Flutter applications**
- Project structure and Riverpod setup.
- Customer screens and booking workflow.
- Professional screens and job workflow.
- Quote approval and disputes.
- Payments, earnings, and transaction history.
- Notifications, maps, and location tracking.
- Loading, empty, offline, and error states.

**Phase 6 — Administration**
- Responsive admin dashboard.
- Professional KYC management.
- Booking monitoring.
- Pricing and commission controls.
- Ledger, settlements, refunds, and payouts.
- Dispute resolution and audit logs.

**Phase 7 — Production readiness**
- Security and integration testing.
- Performance and concurrency testing.
- CI/CD and environment configuration.
- Monitoring, backups, and recovery.
- Android and iOS release checklists.
- Legal and operational launch checklist.

**Phase 8 — Delivery roadmap**
- A 12-week MVP roadmap.
- Weekly milestones and dependencies.
- MVP, V1, and V2 feature prioritization.
- Testing and launch gates.
- Estimated effort and major risks.

After each phase, summarize completed deliverables, relevant files, database changes, tests, outstanding issues, and the next phase.

Then wait for my explicit **CONTINUE** before starting the next phase.

## 23. CODE QUALITY AND DELIVERY REQUIREMENTS

All implementation must follow these rules:
- Use clean, maintainable, modular code.
- Follow SOLID principles where applicable.
- Validate inputs with typed models and server-side validation.
- Use migrations rather than undocumented manual database edits.
- Include environment examples without real secrets.
- Implement meaningful error handling and structured logging.
- Add automated tests for critical financial and booking rules.
- Provide setup instructions and exact commands for local development.
- Keep API contracts, database types, and Flutter models consistent.
- Do not mark incomplete features as implemented.
- Do not use mock payment success or fabricated production data.
- Identify dependencies, setup requirements, and external account approvals.
- Explain how each module integrates with the existing architecture.

When delivering code, identify the file path, provide the complete relevant implementation, explain required configuration, and include the tests needed to verify it.

## 24. FIRST RESPONSE REQUIRED

Start with Phase 1 only.

Before producing implementation code:
1. Summarize the architecture and explain why Supabase is the primary backend.
2. Explain the proposed customer, professional, and admin application structure.
3. Identify the financial architecture and distinguish cash collected, platform dues, professional earnings, and withdrawable balances.
4. List any genuinely unresolved decisions that could materially affect the database, payment flow, or legal obligations.
5. Clearly distinguish confirmed requirements from proposed defaults.
6. Recommend the smallest practical production-ready MVP without removing mandatory financial, security, or booking safeguards.

Do not generate all the code at once. Finish Phase 1, provide its deliverables, and wait for my **CONTINUE** instruction.
