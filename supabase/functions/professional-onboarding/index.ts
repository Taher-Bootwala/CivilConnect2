import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, requiredString, optionalString, number, integer, uuidArray, enumValue } from "../_shared/validation.ts";

type Availability = { dayOfWeek: unknown; startLocal: unknown; endLocal: unknown; timezoneName?: unknown };
type ServiceArea = { latitude: unknown; longitude: unknown; radiusM: unknown; label?: unknown };
type OnboardingRequest = {
  fullName: unknown;
  bio?: unknown;
  experienceYears?: unknown;
  serviceIds: unknown;
  serviceArea: unknown;
  availability: unknown;
};

const weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"] as const;

function safeTime(value: unknown, name: string) {
  if (typeof value !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    throw new HttpError(422, "INVALID_TIME", `${name} must be in HH:mm format.`);
  }
  return value;
}

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for professional onboarding.");
  const { client, user } = await requireUser(request);
  const body = record(await readJson<OnboardingRequest>(request));
  const serviceIds = uuidArray(body.serviceIds, "serviceIds", 30);
  if (serviceIds.length === 0) throw new HttpError(422, "SERVICES_REQUIRED", "Select at least one service.");
  const area = record(body.serviceArea, "serviceArea") as unknown as ServiceArea;
  const availability = body.availability;
  if (!Array.isArray(availability) || availability.length > 14) throw new HttpError(422, "INVALID_AVAILABILITY", "availability must contain at most 14 weekly windows.");

  const profileUpdate = await client.from("profiles").update({ full_name: requiredString(body.fullName, "fullName", 160) }).eq("id", user.id);
  assertNoDatabaseError(profileUpdate);

  const existing = await client.from("labor_profiles").select("user_id, professional_code").eq("user_id", user.id).maybeSingle();
  const existingProfile = assertNoDatabaseError(existing) as { user_id: string; professional_code: string } | null;
  const professionalCode = existingProfile?.professional_code ?? `CC-PRO-${crypto.randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase()}`;
  const laborResult = await client.from("labor_profiles").upsert({
    user_id: user.id,
    professional_code: professionalCode,
    bio: optionalString(body.bio, "bio", 2000) ?? "",
    experience_years: number(body.experienceYears ?? 0, "experienceYears", 0, 80),
    default_travel_radius_m: integer(area.radiusM, "serviceArea.radiusM", 100, 100000),
  }, { onConflict: "user_id" }).select("user_id, professional_code, kyc_status").single();
  const laborProfile = assertNoDatabaseError(laborResult);

  const serviceRows = serviceIds.map((serviceId) => ({ labor_id: user.id, service_id: serviceId }));
  const serviceResult = await client.from("labor_services").upsert(serviceRows, { onConflict: "labor_id,service_id" });
  assertNoDatabaseError(serviceResult);

  const areaResult = await client.from("service_areas").insert({
    labor_id: user.id,
    center: `POINT(${number(area.longitude, "serviceArea.longitude", -180, 180)} ${number(area.latitude, "serviceArea.latitude", -90, 90)})`,
    radius_m: integer(area.radiusM, "serviceArea.radiusM", 100, 100000),
    label: optionalString(area.label, "serviceArea.label", 120),
    is_primary: true,
  });
  assertNoDatabaseError(areaResult);

  const availabilityRows = availability.map((windowValue, index) => {
    const window = record(windowValue, `availability[${index}]`) as unknown as Availability;
    return {
      labor_id: user.id,
      day_of_week: enumValue(window.dayOfWeek, `availability[${index}].dayOfWeek`, weekdays),
      start_local: safeTime(window.startLocal, `availability[${index}].startLocal`),
      end_local: safeTime(window.endLocal, `availability[${index}].endLocal`),
      timezone_name: optionalString(window.timezoneName, `availability[${index}].timezoneName`, 80) ?? "Asia/Kolkata",
    };
  });
  if (availabilityRows.length > 0) {
    const availabilityResult = await client.from("labor_availability").insert(availabilityRows);
    assertNoDatabaseError(availabilityResult);
  }

  return jsonResponse({ professional: laborProfile, kyc_status: "not_started", next_step: "upload_kyc_documents" }, 201);
}));
