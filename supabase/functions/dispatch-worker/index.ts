import { withHttpHandler, HttpError, jsonResponse } from "../_shared/http.ts";
import { adminClient, assertNoDatabaseError } from "../_shared/supabase.ts";

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for dispatch maintenance.");
  const expected = Deno.env.get("DISPATCH_WORKER_SECRET");
  const supplied = request.headers.get("x-worker-secret");
  if (!expected || !supplied || supplied !== expected) throw new HttpError(401, "WORKER_AUTH_REQUIRED", "A valid worker credential is required.");
  const result = await adminClient().rpc("dispatch_expired_assignments");
  return jsonResponse({ expired_assignments: assertNoDatabaseError(result) });
}));
