import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireStaff, adminClient } from "../_shared/supabase.ts";
import { record, requiredString, integer, uuid } from "../_shared/validation.ts";

type ReconciliationRequest = {
  provider: unknown;
  providerReference: unknown;
  paymentId?: unknown;
  payoutId?: unknown;
  expectedAmountPaise?: unknown;
  actualAmountPaise?: unknown;
  notes?: unknown;
};

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to record a reconciliation result.");
  const { user } = await requireStaff(request);
  const body = record(await readJson<ReconciliationRequest>(request));
  const expected = body.expectedAmountPaise == null ? null : integer(body.expectedAmountPaise, "expectedAmountPaise", 0, 100000000000);
  const actual = body.actualAmountPaise == null ? null : integer(body.actualAmountPaise, "actualAmountPaise", 0, 100000000000);
  const status = expected === null || actual === null ? "pending" : expected === actual ? "matched" : "mismatched";
  const admin = adminClient();
  const result = await admin.from("payment_reconciliations").upsert({
    provider: requiredString(body.provider, "provider", 80),
    provider_reference: requiredString(body.providerReference, "providerReference", 200),
    payment_id: body.paymentId == null ? null : uuid(body.paymentId, "paymentId"),
    payout_id: body.payoutId == null ? null : uuid(body.payoutId, "payoutId"),
    expected_amount_paise: expected,
    actual_amount_paise: actual,
    status,
    notes: body.notes == null ? null : requiredString(body.notes, "notes", 2000),
    reconciled_by: user.id,
    reconciled_at: status === "matched" ? new Date().toISOString() : null,
  }, { onConflict: "provider,provider_reference" }).select("id, provider, provider_reference, status, expected_amount_paise, actual_amount_paise").single();
  if (result.error) throw new HttpError(400, "RECONCILIATION_FAILED", result.error.message);
  return jsonResponse({ reconciliation: result.data });
}));
