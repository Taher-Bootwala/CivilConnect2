import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, adminClient, assertNoDatabaseError } from "../_shared/supabase.ts";
import { razorpayRequest, razorpayPublicKey } from "../_shared/razorpay.ts";
import { record, integer } from "../_shared/validation.ts";

type SettlementRequest = { amountPaise: unknown };
type ProviderOrder = { id: string; amount: number; currency: string };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to create a settlement order.");
  const { client } = await requireUser(request);
  const body = record(await readJson<SettlementRequest>(request));
  const idempotencyKey = request.headers.get("idempotency-key") ?? crypto.randomUUID();
  const prepared = await client.rpc("request_cash_settlement", { settlement_amount_paise: integer(body.amountPaise, "amountPaise", 1, 1000000000), request_idempotency_key: idempotencyKey });
  const settlement = (assertNoDatabaseError(prepared) as Array<{ settlement_id: string; amount_paise: number; status: string }>)[0];
  if (!settlement) throw new HttpError(500, "SETTLEMENT_PREPARATION_FAILED", "The settlement could not be prepared.");
  const existing = await adminClient().from("cash_settlements").select("provider_order_id, amount_paise").eq("id", settlement.settlement_id).maybeSingle();
  if (existing.error) throw new HttpError(500, "SETTLEMENT_LOOKUP_FAILED", "The settlement could not be read.");
  if (existing.data?.provider_order_id) return jsonResponse({ settlement_id: settlement.settlement_id, order_id: existing.data.provider_order_id, amount_paise: existing.data.amount_paise, public_key: razorpayPublicKey() });
  const providerOrder = await razorpayRequest<ProviderOrder>("/orders", "POST", { amount: settlement.amount_paise, currency: "INR", receipt: `cc_settlement_${settlement.settlement_id}`, notes: { settlement_id: settlement.settlement_id } });
  if (providerOrder.amount !== settlement.amount_paise || providerOrder.currency !== "INR") throw new HttpError(502, "PROVIDER_AMOUNT_MISMATCH", "Razorpay returned an unexpected settlement amount.");
  const saved = await adminClient().from("cash_settlements").update({ provider_order_id: providerOrder.id }).eq("id", settlement.settlement_id).is("provider_order_id", null);
  if (saved.error) throw new HttpError(502, "SETTLEMENT_ORDER_PERSIST_FAILED", "The settlement order could not be persisted.");
  return jsonResponse({ settlement_id: settlement.settlement_id, order_id: providerOrder.id, amount_paise: settlement.amount_paise, public_key: razorpayPublicKey() }, 201);
}));
