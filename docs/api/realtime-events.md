# Realtime and notification event contract

Supabase Realtime is a delivery channel, not the source of truth. Clients subscribe only after authentication and must reload the authorized row from the API after reconnecting or app restart.

## Channels

| Channel | Table/event | Authorized subscribers | Purpose |
|---|---|---|---|
| `booking:{booking_id}` | `bookings`, `booking_status_history` | Customer, assigned professional, staff | Booking lifecycle and transition history |
| `assignment:{professional_id}` | `booking_assignments` | Target professional, operations staff | New request, response, expiry, reassignment |
| `location:{booking_id}` | `labor_live_location` | Customer, assigned professional, staff while active | Battery-conscious arrival/on-the-way location |
| `quote:{booking_id}` | `booking_amount_proposals`, `disputes` | Customer, assigned professional, staff | Quote submission, approval, dispute |
| `payment:{booking_id}` | `payments` | Customer, assigned professional, finance staff | Verified payment state only |
| `settlement:{professional_id}` | `cash_settlements`, `professional_payouts` | Professional, finance staff | Settlement and payout updates |
| `chat:{booking_id}` | `chat_messages` | Booking participants | In-app chat without direct phone exposure |
| `inbox:{user_id}` | `notifications` | Owning user | Persisted notification inbox |

## Event handling rules

1. Edge Functions write the authoritative row and audit/status history first.
2. Realtime broadcasts follow the committed database change.
3. FCM sends a concise notification with an entity ID, never a sensitive payload or secret.
4. A client receiving an event fetches the current authorized record; it does not infer financial success from the event alone.
5. On reconnect, the client refreshes active bookings, pending assignments, quotes, payments, notifications, and settlements.

## Core event names

`booking.requested`, `booking.dispatched`, `booking.accepted`, `booking.rejected`, `booking.expired`, `booking.on_the_way`, `booking.arrived`, `booking.work_started`, `booking.work_done`, `quote.submitted`, `quote.approved`, `quote.disputed`, `payment.pending`, `payment.captured`, `payment.failed`, `cash.exposure_warning`, `settlement.pending`, `settlement.verified`, `payout.processed`, `kyc.submitted`, `kyc.approved`, `kyc.rejected`, `support.updated`, and `sos.opened`.
