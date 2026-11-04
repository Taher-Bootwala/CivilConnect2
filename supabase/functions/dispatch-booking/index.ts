import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, uuid, integer } from "../_shared/validation.ts";

type DispatchRequest = { bookingId: unknown; maxCandidates?: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to dispatch a booking.");
  const { client } = await requireUser(request);
  const body = record(await readJson<DispatchRequest>(request));
  const bookingId = uuid(body.bookingId, "bookingId");
  const maxCandidates = integer(body.maxCandidates ?? 3, "maxCandidates", 1, 10);

  const bookingResult = await client.rpc("get_booking_dispatch_context", { booking_uuid: bookingId });
  const contexts = assertNoDatabaseError(bookingResult) as Array<Record<string, unknown>>;
  const booking = contexts[0] ?? null;
  if (!booking) throw new HttpError(404, "BOOKING_NOT_FOUND", "Booking was not found.");
  if (booking.booking_mode !== "automatic_match") throw new HttpError(409, "NOT_AUTOMATIC_BOOKING", "Only automatic-match bookings can be dispatched.");
  const nearby = await client.rpc("find_nearby_professionals", {
    service_uuid: booking.service_id,
    latitude: booking.latitude,
    longitude: booking.longitude,
    requested_start: booking.scheduled_start,
    requested_end: booking.scheduled_end,
    result_limit: Math.max(maxCandidates, 10),
  });
  const candidates = assertNoDatabaseError(nearby) as Array<{ professional_id: string }>;
  const assignmentResult = await client.rpc("create_dispatch_assignments", {
    booking_uuid: bookingId,
    candidate_ids: candidates.slice(0, maxCandidates).map((candidate) => candidate.professional_id),
    max_candidates: maxCandidates,
  });
  const created = assertNoDatabaseError(assignmentResult);
  if (created === 0) throw new HttpError(409, "NO_ELIGIBLE_PROFESSIONALS", "No eligible professionals are available for this appointment.");
  return jsonResponse({ booking_id: bookingId, assignments_created: created });
}));
