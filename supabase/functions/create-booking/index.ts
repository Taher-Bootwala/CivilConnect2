import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, uuid, number, isoDate, enumValue, requiredString, optionalString } from "../_shared/validation.ts";

type BookingRequest = {
  serviceId: unknown;
  mode: unknown;
  selectedProfessionalId?: unknown;
  scheduledStart: unknown;
  scheduledEnd: unknown;
  problemDescription: unknown;
  latitude: unknown;
  longitude: unknown;
  accuracyM?: unknown;
  addressSnapshot: unknown;
  flatNumber?: unknown;
  landmark?: unknown;
  directions?: unknown;
};

Deno.serve(withHttpHandler(async (request, requestId) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to create a booking.");
  const { client } = await requireUser(request);
  const body = record(await readJson<BookingRequest>(request));
  const mode = enumValue(body.mode, "mode", ["selected_professional", "automatic_match"] as const);
  const selectedProfessionalId = body.selectedProfessionalId == null ? null : uuid(body.selectedProfessionalId, "selectedProfessionalId");
  const idempotencyKey = request.headers.get("idempotency-key") ?? crypto.randomUUID();
  if (idempotencyKey.length > 120) throw new HttpError(422, "INVALID_IDEMPOTENCY_KEY", "Idempotency-Key must be at most 120 characters.");

  const result = await client.rpc("create_booking", {
    service_uuid: uuid(body.serviceId, "serviceId"),
    mode,
    selected_professional_uuid: selectedProfessionalId,
    requested_start: isoDate(body.scheduledStart, "scheduledStart"),
    requested_end: isoDate(body.scheduledEnd, "scheduledEnd"),
    problem: requiredString(body.problemDescription, "problemDescription", 4000),
    latitude: number(body.latitude, "latitude", -90, 90),
    longitude: number(body.longitude, "longitude", -180, 180),
    accuracy_m: body.accuracyM == null ? null : number(body.accuracyM, "accuracyM", 0, 10000),
    address_snapshot: requiredString(body.addressSnapshot, "addressSnapshot", 500),
    flat_number: optionalString(body.flatNumber, "flatNumber", 120),
    landmark: optionalString(body.landmark, "landmark", 240),
    directions: optionalString(body.directions, "directions", 1000),
    idempotency_key: idempotencyKey,
  });
  const bookingId = assertNoDatabaseError(result);
  return jsonResponse({ booking_id: bookingId, request_id: requestId, payment_required_now: false }, 201);
}));
