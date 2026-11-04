import { withHttpHandler, HttpError, jsonResponse } from "../_shared/http.ts";
import { adminClient, requireStaff } from "../_shared/supabase.ts";

async function count(table: string, filters: Array<[string, string]> = []) {
  let query = adminClient().from(table).select('*', { count: 'exact', head: true });
  for (const [column, value] of filters) query = query.eq(column, value);
  const result = await query;
  if (result.error) throw new HttpError(500, "ADMIN_METRICS_QUERY_FAILED", result.error.message);
  return result.count ?? 0;
}

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "GET") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use GET for dashboard metrics.");
  await requireStaff(request);
  const [todayBookings, activeBookings, openDisputes, postedJournals] = await Promise.all([
    count('bookings', [['booking_status', 'requested']]),
    count('bookings', [['booking_status', 'in_progress']]),
    count('disputes', [['status', 'open']]),
    count('ledger_transactions', [['status', 'posted']]),
  ]);
  return jsonResponse({ metrics: [
    { label: 'Bookings today', value: String(todayBookings), note: 'Requested state count', tone: 'amber' },
    { label: 'Active jobs', value: String(activeBookings), note: 'Work in progress', tone: 'teal' },
    { label: 'Open disputes', value: String(openDisputes), note: 'Requires support review', tone: 'coral' },
    { label: 'Posted journals', value: String(postedJournals), note: 'Balanced ledger records', tone: 'ink' },
  ] });
}));
