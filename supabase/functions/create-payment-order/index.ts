import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, adminClient, assertNoDatabaseError } from "../_shared/supabase.ts";
import { razorpayRequest, razorpayPublicKey } from "../_shared/razorpay.ts";
import { record, uuid } from "../_shared/validation.ts";

type OrderRequest = { bookingId: unknown };
type ProviderOrder = { id: string; amount: number; currency: string; status: string };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to create a payment order.");
  const { client, user } = await requireUser(request);
  const body = record(await readJson<OrderRequest>(request));
  const bookingId = uuid(body.bookingId, "bookingId");
  const idempotencyKey = request.headers.get("idempotency-key") ?? crypto.randomUUID();
  const prepared = await client.rpc("prepare_online_payment", { booking_uuid: bookingId, request_idempotency_key: idempotencyKey });
  const payment = (assertNoDatabaseError(prepared) as Array<{ payment_id: string; amount_paise: number; currency: string }>)[0];
  if (!payment) throw new HttpError(500, "PAYMENT_PREPARATION_FAILED", "The payment could not be prepared.");

  const existingOrder = await adminClient().from("payment_provider_orders").select("provider_order_id, amount_paise, currency, status").eq("payment_id", payment.payment_id).maybeSingle();
  if (existingOrder.error) throw new HttpError(500, "PAYMENT_LOOKUP_FAILED", "The payment order could not be read.");
  if (existingOrder.data) {
    return jsonResponse({ payment_id: payment.payment_id, order_id: existingOrder.data.provider_order_id, amount_paise: existingOrder.data.amount_paise, currency: existingOrder.data.currency, public_key: razorpayPublicKey() });
  }

  const providerOrder = await razorpayRequest<ProviderOrder>("/orders", "POST", {
    amount: payment.amount_paise,
    currency: payment.currency,
    receipt: `cc_${payment.payment_id}`,
    notes: { booking_id: bookingId, customer_id: user.id },
  });
  if (providerOrder.amount !== payment.amount_paise || providerOrder.currency !== payment.currency) throw new HttpError(502, "PROVIDER_AMOUNT_MISMATCH", "Razorpay returned an unexpected amount.");
  const inserted = await adminClient().from("payment_provider_orders").insert({
    payment_id: payment.payment_id,
    provider: "razorpay",
    provider_order_id: providerOrder.id,
    amount_paise: payment.amount_paise,
    currency: payment.currency,
    status: "order_created",
  });
  if (inserted.error) throw new HttpError(502, "PAYMENT_ORDER_PERSIST_FAILED", "The payment order could not be persisted.");
  return jsonResponse({ payment_id: payment.payment_id, order_id: providerOrder.id, amount_paise: payment.amount_paise, currency: payment.currency, public_key: razorpayPublicKey() }, 201);
}));
