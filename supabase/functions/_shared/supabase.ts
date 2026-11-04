import { createClient, type SupabaseClient, type User } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { HttpError } from "./http.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !anonKey || !serviceRoleKey) {
  console.warn("Supabase function environment is incomplete; configure secrets before deployment.");
}

export function userClient(request: Request): SupabaseClient {
  const authorization = request.headers.get("Authorization");
  return createClient(supabaseUrl ?? "", anonKey ?? "", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: authorization ? { Authorization: authorization } : {} },
  });
}

export function adminClient(): SupabaseClient {
  return createClient(supabaseUrl ?? "", serviceRoleKey ?? "", {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireUser(request: Request) {
  const token = request.headers.get("Authorization");
  if (!token?.startsWith("Bearer ")) {
    throw new HttpError(401, "AUTH_REQUIRED", "A Supabase access token is required.");
  }
  const client = userClient(request);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new HttpError(401, "INVALID_SESSION", "The Supabase session is invalid or expired.");
  }
  return { client, user: data.user as User };
}

export async function requireStaff(request: Request) {
  const { client, user } = await requireUser(request);
  const { data, error } = await client
    .from("admin_roles")
    .select("role, permissions")
    .eq("user_id", user.id)
    .is("revoked_at", null)
    .maybeSingle();
  if (error || !data) throw new HttpError(403, "STAFF_REQUIRED", "An authorized staff role is required.");
  return { client, user, role: data.role as string, permissions: data.permissions as Record<string, unknown> };
}

export function assertNoDatabaseError<T>(result: { data: T; error: { message: string; code?: string } | null }) {
  if (result.error) {
    console.error(JSON.stringify({ database_code: result.error.code, database_message: result.error.message }));
    throw new HttpError(400, "DATABASE_OPERATION_FAILED", result.error.message);
  }
  return result.data;
}
