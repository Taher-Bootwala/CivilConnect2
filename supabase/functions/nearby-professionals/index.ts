import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, uuid, number, integer, isoDate } from "../_shared/validation.ts";

type NearbyRequest = {
  serviceId: unknown;
  latitude: unknown;
  longitude: unknown;
  scheduledStart: unknown;
  scheduledEnd: unknown;
  limit?: unknown;
};

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for professional search.");
  const { client } = await requireUser(request);
  const body = record(await readJson<NearbyRequest>(request));
  const result = await client.rpc("find_nearby_professionals", {
    service_uuid: uuid(body.serviceId, "serviceId"),
    latitude: number(body.latitude, "latitude", -90, 90),
    longitude: number(body.longitude, "longitude", -180, 180),
    requested_start: isoDate(body.scheduledStart, "scheduledStart"),
    requested_end: isoDate(body.scheduledEnd, "scheduledEnd"),
    result_limit: integer(body.limit ?? 20, "limit", 1, 100),
  });
  return jsonResponse({ professionals: assertNoDatabaseError(result) });
}));
