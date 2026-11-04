import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, optionalString } from "../_shared/validation.ts";

Deno.serve(withHttpHandler(async (request) => {
  const { client, user } = await requireUser(request);
  if (request.method === "GET") {
    const result = await client
      .from("profiles")
      .select("id, email, phone, full_name, avatar_path, primary_role, account_status, phone_verified_at, email_verified_at, customer_profiles(*), labor_profiles(*)")
      .eq("id", user.id)
      .single();
    return jsonResponse({ profile: assertNoDatabaseError(result) });
  }
  if (request.method !== "PATCH") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use GET or PATCH for profiles.");
  const body = record(await readJson<Record<string, unknown>>(request));
  const changes: Record<string, string | null> = {};
  if (body.fullName !== undefined) changes.full_name = optionalString(body.fullName, "fullName", 160);
  if (body.avatarPath !== undefined) {
    const avatarPath = optionalString(body.avatarPath, "avatarPath", 500);
    if (avatarPath !== null && !avatarPath.startsWith(`avatars/${user.id}/`)) {
      throw new HttpError(403, "INVALID_AVATAR_PATH", "Avatar files must belong to the authenticated user.");
    }
    changes.avatar_path = avatarPath;
  }
  if (Object.keys(changes).length === 0) throw new HttpError(422, "NO_CHANGES", "Provide a profile field to update.");
  const result = await client.from("profiles").update(changes).eq("id", user.id).select("id, email, phone, full_name, avatar_path, primary_role, account_status").single();
  return jsonResponse({ profile: assertNoDatabaseError(result) });
}));
