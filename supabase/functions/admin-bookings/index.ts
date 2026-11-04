import { withHttpHandler, HttpError, jsonResponse } from "../_shared/http.ts";
import { adminClient, requireStaff } from "../_shared/supabase.ts";

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "GET") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use GET for admin bookings.");
  await requireStaff(request);
  const url = new URL(request.url);
  const limit = Math.max(1, Math.min(Number(url.searchParams.get('limit') ?? 50), 100));
  const result = await adminClient().from('bookings').select('id, booking_number, booking_status, payment_status, scheduled_start, customer_id, assigned_labor_id, services(name)').order('scheduled_start', { ascending: false }).limit(limit);
  if (result.error) throw new HttpError(500, "ADMIN_BOOKINGS_QUERY_FAILED", result.error.message);
  return jsonResponse({ bookings: (result.data ?? []).map((booking) => ({ id: booking.booking_number ?? booking.id, service: (booking.services as { name?: string } | null)?.name ?? 'Service', customer: booking.customer_id, professional: booking.assigned_labor_id ?? 'Unassigned', status: booking.booking_status, amount: booking.payment_status, time: booking.scheduled_start })) });
}));
