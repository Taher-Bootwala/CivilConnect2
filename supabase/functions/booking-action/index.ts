import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, uuid, enumValue, optionalString, requiredString, number } from "../_shared/validation.ts";

const actions = ["accept", "reject", "on_the_way", "arrive", "start", "work_done", "cancel"] as const;
type BookingAction = typeof actions[number];
type ActionRequest = {
  bookingId: unknown;
  action: unknown;
  reason?: unknown;
  otp?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  accuracyM?: unknown;
};

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for booking actions.");
  const { client } = await requireUser(request);
  const body = record(await readJson<ActionRequest>(request));
  const bookingId = uuid(body.bookingId, "bookingId");
  const action = enumValue(body.action, "action", actions);
  const reason = optionalString(body.reason, "reason", 500);

  if (action === "accept" || action === "reject") {
    const result = await client.rpc("respond_to_booking_assignment", {
      booking_uuid: bookingId,
      accept_request: action === "accept",
      rejection_reason: action === "reject" ? reason : null,
    });
    return jsonResponse({ booking_id: bookingId, booking_status: assertNoDatabaseError(result) });
  }

  if (action === "arrive") {
    const result = await client.rpc("verify_arrival", {
      booking_uuid: bookingId,
      latitude: number(body.latitude, "latitude", -90, 90),
      longitude: number(body.longitude, "longitude", -180, 180),
      accuracy: body.accuracyM == null ? null : number(body.accuracyM, "accuracyM", 0, 10000),
    });
    const verified = assertNoDatabaseError(result);
    if (!verified) throw new HttpError(422, "ARRIVAL_NOT_VERIFIED", "Professional is outside the configured arrival geofence or GPS accuracy is insufficient.");
    return jsonResponse({ booking_id: bookingId, booking_status: "arrived", location_verified: true });
  }

  if (action === "start") {
    const otp = requiredString(body.otp, "otp", 12);
    const result = await client.rpc("verify_start_otp", { booking_uuid: bookingId, otp });
    const verified = assertNoDatabaseError(result);
    if (!verified) throw new HttpError(422, "INVALID_START_OTP", "The start OTP is invalid or expired.");
    return jsonResponse({ booking_id: bookingId, booking_status: "in_progress" });
  }

  const nextStatus = action === "on_the_way" ? "on_the_way" : action === "work_done" ? "work_done" : "cancelled";
  const result = await client.rpc("transition_booking_status", {
    booking_uuid: bookingId,
    next_status: nextStatus,
    transition_reason: reason,
    transition_metadata: { source: "booking-action" },
  });
  return jsonResponse({ booking_id: bookingId, booking_status: assertNoDatabaseError(result) });
}));
