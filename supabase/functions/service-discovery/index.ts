import { withHttpHandler, HttpError, jsonResponse } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { optionalString, integer } from "../_shared/validation.ts";

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "GET") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use GET for service discovery.");
  const { client } = await requireUser(request);
  const url = new URL(request.url);
  const query = optionalString(url.searchParams.get("q"), "q", 120);
  const limit = integer(url.searchParams.get("limit") ?? 50, "limit", 1, 100);

  let servicesQuery = client
    .from("services")
    .select("id, category_id, slug, name, description, typical_duration_minutes, estimate_min_paise, estimate_max_paise, visiting_charge_policy")
    .eq("status", "active")
    .order("name")
    .limit(limit);
  if (query) servicesQuery = servicesQuery.ilike("name", `%${query}%`);

  const [categories, services] = await Promise.all([
    client.from("service_categories").select("id, slug, name, description, icon_name, sort_order").eq("status", "active").order("sort_order"),
    servicesQuery,
  ]);
  return jsonResponse({
    categories: assertNoDatabaseError(categories),
    services: assertNoDatabaseError(services),
  });
}));
