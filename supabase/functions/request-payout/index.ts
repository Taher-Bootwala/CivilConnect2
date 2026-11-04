import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, integer } from "../_shared/validation.ts";

type PayoutRequest = { amountPaise: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to request a payout.");
  const { client } = await requireUser(request);
  if (Deno.env.get("RAZORPAY_PAYOUTS_ENABLED") !== "true") throw new HttpError(409, "PAYOUT_PROVIDER_NOT_ACTIVATED", "Professional payouts remain disabled until the approved Razorpay marketplace fund flow is activated.");
  const body = record(await readJson<PayoutRequest>(request));
  const idempotencyKey = request.headers.get("idempotency-key") ?? crypto.randomUUID();
  const result = await client.rpc("request_professional_payout", { payout_amount_paise: integer(body.amountPaise, "amountPaise", 1, 1000000000), request_idempotency_key: idempotencyKey });
  const payout = (assertNoDatabaseError(result) as Array<{ payout_id: string; amount_paise: number; status: string; eligible_balance_paise: number }>)[0];
  return jsonResponse({ payout, status: "pending_provider_processing" }, 201);
}));
