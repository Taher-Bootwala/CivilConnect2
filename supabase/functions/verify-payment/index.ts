import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, adminClient, assertNoDatabaseError } from "../_shared/supabase.ts";
import { razorpayRequest, verifyHmac } from "../_shared/razorpay.ts";
import { record, requiredString, uuid } from "../_shared/validation.ts";

type VerifyRequest = { paymentId: unknown; orderId: unknown; providerPaymentId: unknown; signature: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to verify a payment.");
  const { client } = await requireUser(request);
  const body = record(await readJson<VerifyRequest>(request));
  const paymentId = uuid(body.paymentId, "paymentId");
  const orderId = requiredString(body.orderId, "orderId", 120);
  const providerPaymentId = requiredString(body.providerPaymentId, "providerPaymentId", 120);
  const signature = requiredString(body.signature, "signature", 200);
  const payment = await client.from("payments").select("id, booking_id, amount_paise, status").eq("id", paymentId).maybeSingle();
  const paymentRow = assertNoDatabaseError(payment) as { id: string; booking_id: string; amount_paise: number; status: string } | null;
  if (!paymentRow) throw new HttpError(404, "PAYMENT_NOT_FOUND", "Payment was not found.");
  const providerOrder = await client.from("payment_provider_orders").select("provider_order_id, amount_paise").eq("payment_id", paymentId).maybeSingle();
  const orderRow = assertNoDatabaseError(providerOrder) as { provider_order_id: string; amount_paise: number } | null;
  if (!orderRow || orderRow.provider_order_id !== orderId || orderRow.amount_paise !== paymentRow.amount_paise) throw new HttpError(422, "PAYMENT_ORDER_MISMATCH", "The provider order does not match the server payment.");
  const secret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!secret || !await verifyHmac(`${orderId}|${providerPaymentId}`, signature, secret)) throw new HttpError(422, "INVALID_PAYMENT_SIGNATURE", "The payment signature could not be verified.");
  const providerPayment = await razorpayRequest<{ id: string; order_id: string; amount: number; status: string }>(`/payments/${encodeURIComponent(providerPaymentId)}`, "GET");
  if (providerPayment.id !== providerPaymentId || providerPayment.order_id !== orderId || providerPayment.amount !== paymentRow.amount_paise || providerPayment.status !== "captured") {
    throw new HttpError(409, "PAYMENT_NOT_CAPTURED", "Razorpay has not confirmed this payment as captured.");
  }

  const captured = await adminClient().rpc("capture_online_payment", {
    payment_uuid: paymentId,
    provider_payment_uuid: providerPaymentId,
    provider_order_uuid: orderId,
    verification_source: "provider_api_verification",
  });
  return jsonResponse({ payment_id: paymentId, payment_status: assertNoDatabaseError(captured), provider_confirmation_required: true });
}));
