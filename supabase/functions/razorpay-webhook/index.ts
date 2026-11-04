import { withHttpHandler, HttpError, jsonResponse } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";
import { verifyHmac } from "../_shared/razorpay.ts";

type RazorpayPayload = Record<string, any>;

function payloadValue(payload: RazorpayPayload, path: string[]) {
  let current: any = payload;
  for (const key of path) current = current?.[key];
  return current;
}

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for Razorpay webhooks.");
  const rawBody = await request.text();
  const signature = request.headers.get("x-razorpay-signature");
  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  if (!signature || !secret || !await verifyHmac(rawBody, signature, secret)) throw new HttpError(401, "INVALID_WEBHOOK_SIGNATURE", "The Razorpay webhook signature is invalid.");
  let payload: RazorpayPayload;
  try {
    payload = JSON.parse(rawBody) as RazorpayPayload;
  } catch {
    throw new HttpError(400, "INVALID_WEBHOOK_BODY", "The webhook body is not valid JSON.");
  }
  const eventType = typeof payload.event === "string" ? payload.event : "unknown";
  const eventId = request.headers.get("x-razorpay-event-id") ?? payload.id;
  if (typeof eventId !== "string" || eventId.length === 0) throw new HttpError(400, "MISSING_WEBHOOK_ID", "The Razorpay event ID is required.");
  const admin = adminClient();
  const payloadHash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(rawBody));
  const hash = Array.from(new Uint8Array(payloadHash)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
  const inserted = await admin.from("payment_provider_events").insert({ provider: "razorpay", provider_event_id: eventId, event_type: eventType, payload_hash: hash, raw_payload: payload, signature_verified: true });
  let retryingFailedEvent = false;
  if (inserted.error?.code === "23505") {
    const previous = await admin.from("payment_provider_events").select("processed_at, processing_error").eq("provider", "razorpay").eq("provider_event_id", eventId).maybeSingle();
    if (previous.data?.processed_at || !previous.data?.processing_error) return jsonResponse({ received: true, duplicate: true });
    retryingFailedEvent = true;
  }
  if (inserted.error && !retryingFailedEvent) throw new HttpError(500, "WEBHOOK_PERSIST_FAILED", "The webhook event could not be persisted.");

  try {
    if (eventType === "payment.captured" || eventType === "order.paid") {
      const providerPaymentId = payloadValue(payload, ["payload", "payment", "entity", "id"]);
      const providerOrderId = payloadValue(payload, ["payload", "payment", "entity", "order_id"]) ?? payloadValue(payload, ["payload", "order", "entity", "id"]);
      const providerAmount = payloadValue(payload, ["payload", "payment", "entity", "amount"]);
      if (typeof providerPaymentId === "string" && typeof providerOrderId === "string") {
        const settlement = await admin.from("cash_settlements").select("id, provider_order_id").eq("provider_order_id", providerOrderId).maybeSingle();
        if (settlement.data && typeof providerAmount === "number") {
          await admin.rpc("verify_cash_settlement", { settlement_uuid: settlement.data.id, provider_payment_uuid: providerPaymentId, provider_order_uuid: providerOrderId, provider_amount_paise: providerAmount });
        } else {
          await admin.from("payment_provider_orders").select("payment_id").eq("provider_order_id", providerOrderId).maybeSingle().then(async (order) => {
            if (order.data) await admin.rpc("capture_online_payment", { payment_uuid: order.data.payment_id, provider_payment_uuid: providerPaymentId, provider_order_uuid: providerOrderId, verification_source: "razorpay_webhook" });
          });
        }
      }
    } else if (eventType === "payment.failed") {
      const providerOrderId = payloadValue(payload, ["payload", "payment", "entity", "order_id"]);
      const reason = payloadValue(payload, ["payload", "payment", "entity", "error_description"]) ?? "Razorpay payment failed";
      const order = await admin.from("payment_provider_orders").select("payment_id").eq("provider_order_id", providerOrderId).maybeSingle();
      if (order.data) await admin.rpc("mark_online_payment_failed", { payment_uuid: order.data.payment_id, failure_reason: String(reason).slice(0, 500) });
    } else if (eventType === "refund.processed") {
      const providerRefundId = payloadValue(payload, ["payload", "refund", "entity", "id"]);
      const providerPaymentId = payloadValue(payload, ["payload", "refund", "entity", "payment_id"]);
      const refund = await admin.from("refunds").select("id").eq("provider_refund_id", providerRefundId).maybeSingle();
      if (refund.data) await admin.rpc("post_processed_refund", { refund_uuid: refund.data.id, provider_refund_uuid: providerRefundId });
      else if (typeof providerPaymentId === "string") {
        const payment = await admin.from("payments").select("id").eq("provider_payment_id", providerPaymentId).maybeSingle();
        if (payment.data) {
          const pending = await admin.from("refunds").select("id").eq("status", "requested").eq("payment_id", payment.data.id).order("created_at", { ascending: true }).limit(1).maybeSingle();
          if (pending.data) await admin.rpc("post_processed_refund", { refund_uuid: pending.data.id, provider_refund_uuid: providerRefundId });
        }
      }
    } else if (eventType === "payout.processed") {
      const providerPayoutId = payloadValue(payload, ["payload", "payout", "entity", "id"]);
      if (typeof providerPayoutId === "string") {
        const payout = await admin.from("professional_payouts").select("id").eq("provider_payout_id", providerPayoutId).maybeSingle();
        if (payout.data) await admin.rpc("post_processed_payout", { payout_uuid: payout.data.id, provider_payout_uuid: providerPayoutId });
      }
    } else if (eventType === "payout.failed") {
      const providerPayoutId = payloadValue(payload, ["payload", "payout", "entity", "id"]);
      if (typeof providerPayoutId === "string") {
        await admin.from("professional_payouts").update({ status: "failed", failure_reason: "Razorpay payout failed" }).eq("provider_payout_id", providerPayoutId);
      }
    }
    await admin.from("payment_provider_events").update({ processed_at: new Date().toISOString() }).eq("provider_event_id", eventId).eq("provider", "razorpay");
  } catch (error) {
    await admin.from("payment_provider_events").update({ processing_error: error instanceof Error ? error.message : "provider event processing failed" }).eq("provider_event_id", eventId).eq("provider", "razorpay");
    throw error;
  }
  return jsonResponse({ received: true });
}));
