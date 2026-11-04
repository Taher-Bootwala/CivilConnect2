import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, uuid, integer, requiredString } from "../_shared/validation.ts";

type RefundRequest = { bookingId: unknown; amountPaise: unknown; reason: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to request a refund.");
  const { client } = await requireUser(request);
  const body = record(await readJson<RefundRequest>(request));
  const idempotencyKey = request.headers.get("idempotency-key") ?? crypto.randomUUID();
  const result = await client.rpc("request_refund", {
    booking_uuid: uuid(body.bookingId, "bookingId"),
    requested_amount_paise: integer(body.amountPaise, "amountPaise", 1, 1000000000),
    refund_reason: requiredString(body.reason, "reason", 1000),
    request_idempotency_key: idempotencyKey,
  });
  return jsonResponse({ refund_id: assertNoDatabaseError(result), status: "requested" }, 201);
}));
