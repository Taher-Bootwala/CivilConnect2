import { withHttpHandler, HttpError, jsonResponse } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for reconciliation maintenance.");
  const expected = Deno.env.get("RECONCILIATION_WORKER_SECRET");
  if (!expected || request.headers.get("x-worker-secret") !== expected) throw new HttpError(401, "WORKER_AUTH_REQUIRED", "A valid reconciliation worker credential is required.");
  const admin = adminClient();
  const pendingEvents = await admin.from("payment_provider_events").select("id, provider, provider_event_id, event_type, processing_error").is("processed_at", null).not("processing_error", "is", null).order("created_at", { ascending: true }).limit(100);
  if (pendingEvents.error) throw new HttpError(500, "RECONCILIATION_QUERY_FAILED", pendingEvents.error.message);
  const pendingReconciliations = await admin.from("payment_reconciliations").select("id, provider, provider_reference, status").in("status", ["pending", "mismatched"]).order("created_at", { ascending: true }).limit(100);
  if (pendingReconciliations.error) throw new HttpError(500, "RECONCILIATION_QUERY_FAILED", pendingReconciliations.error.message);
  return jsonResponse({ queued_provider_events: pendingEvents.data?.length ?? 0, pending_reconciliations: pendingReconciliations.data?.length ?? 0, action: "Provider API reconciliation must be configured before records are marked matched." });
}));
