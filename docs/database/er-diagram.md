# CivilConnect database ER diagram

The diagram shows the principal relationships. Supporting tables such as audit, notification, provider-event, and reconciliation records attach to the relevant aggregate but are omitted from some edges for readability.

```mermaid
erDiagram
  AUTH_USERS ||--|| PROFILES : owns
  PROFILES ||--o| CUSTOMER_PROFILES : has
  PROFILES ||--o| LABOR_PROFILES : has
  LABOR_PROFILES ||--o{ LABOR_KYC : submits
  LABOR_PROFILES ||--o{ LABOR_SERVICES : offers
  SERVICES ||--o{ LABOR_SERVICES : mapped
  SERVICE_CATEGORIES ||--o{ SERVICES : groups
  SERVICES ||--o{ SERVICE_PRICE_GUIDE_ITEMS : guides
  LABOR_PROFILES ||--o{ LABOR_AVAILABILITY : defines
  LABOR_PROFILES ||--o{ SERVICE_AREAS : serves

  CUSTOMER_PROFILES ||--o{ BOOKINGS : creates
  SERVICES ||--o{ BOOKINGS : requested
  LABOR_PROFILES ||--o{ BOOKINGS : selected_or_assigned
  BOOKINGS ||--|| BOOKING_LOCATIONS : has
  BOOKINGS ||--o{ BOOKING_MEDIA : includes
  BOOKINGS ||--o{ BOOKING_STATUS_HISTORY : records
  BOOKINGS ||--o{ BOOKING_ASSIGNMENTS : dispatches
  BOOKINGS ||--o| WORK_SESSIONS : verifies
  BOOKINGS ||--o{ BOOKING_VERIFICATIONS : checks
  BOOKINGS ||--o{ BOOKING_QUOTES : receives
  BOOKING_QUOTES ||--o{ QUOTE_LINE_ITEMS : contains
  BOOKINGS ||--o{ CANCELLATION_PENALTIES : may_create

  BOOKINGS ||--o{ PAYMENTS : settled_by
  PAYMENTS ||--o{ PAYMENT_PROVIDER_ORDERS : orders
  PAYMENTS ||--o{ REFUNDS : reverses
  BOOKINGS ||--o| INVOICES : produces
  PAYMENTS ||--o{ LEDGER_TRANSACTIONS : sources
  LEDGER_TRANSACTIONS ||--o{ LEDGER_ENTRIES : balances
  LEDGER_ACCOUNTS ||--o{ LEDGER_ENTRIES : posts
  LABOR_PROFILES ||--o{ PLATFORM_RECEIVABLES : owes
  LABOR_PROFILES ||--o{ CASH_SETTLEMENTS : settles
  LABOR_PROFILES ||--o{ PROFESSIONAL_PAYOUTS : receives

  BOOKINGS ||--o| DISPUTES : may_have
  DISPUTES ||--o{ DISPUTE_EVENTS : records
  BOOKINGS ||--o| CHAT_THREADS : enables
  CHAT_THREADS ||--o{ CHAT_MESSAGES : contains
  PROFILES ||--o{ NOTIFICATIONS : receives
  BOOKINGS ||--o{ RATINGS : reviews
  BOOKINGS ||--o{ SUPPORT_TICKETS : supports
  PROMO_CODES ||--o{ PROMOTIONAL_REDEMPTIONS : redeemed
  BOOKINGS ||--o| PROMOTIONAL_REDEMPTIONS : discounts

  PROFILES {
    uuid id PK
    app_role primary_role
    account_status account_status
    timestamptz phone_verified_at
  }
  LABOR_PROFILES {
    uuid user_id PK,FK
    kyc_status kyc_status
    boolean is_online
    numeric average_rating
    bigint default_travel_radius_m
  }
  BOOKINGS {
    uuid id PK
    uuid customer_id FK
    uuid assigned_labor_id FK
    booking_status booking_status
    payment_status payment_status
    settlement_status settlement_status
    tstzrange appointment_range
  }
  BOOKING_QUOTES {
    uuid id PK
    uuid booking_id FK
    bigint customer_payable_paise
    bigint professional_earnings_paise
    jsonb pricing_snapshot
  }
  PAYMENTS {
    uuid id PK
    uuid booking_id FK
    payment_method method
    payment_status status
    bigint amount_paise
  }
  LEDGER_TRANSACTIONS {
    uuid id PK
    text reference UK
    ledger_transaction_status status
    text transaction_type
  }
```

## Aggregate boundaries

- **Identity:** `profiles`, customer/professional profiles, KYC, admin roles, devices.
- **Catalog:** categories, services, price guides, effective-dated pricing, labor mappings and availability.
- **Booking:** booking, location snapshot, media, dispatch attempts, state history, work verification, quote versions.
- **Money:** payments/provider events, refunds, immutable pricing snapshot, ledger journals/entries, receivables, settlements, payouts, reconciliation.
- **Experience:** ratings, notifications, chat, disputes, tickets, promotions, saved addresses/professionals.
- **Governance:** audit logs, configuration, consents, deletion, policy versions, SOS.

The database uses `profiles.id` as the canonical identity key and does not duplicate authentication records in customer or professional tables.
