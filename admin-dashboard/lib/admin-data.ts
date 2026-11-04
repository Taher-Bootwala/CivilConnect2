import type { AdminSession, BookingRow, DashboardMetric } from './types';
import { getSupabaseBrowserClient, invokeAdminFunction } from './supabase';

export const emptyMetrics: DashboardMetric[] = [
  { label: 'Bookings today', value: '—', note: 'Connect to load live operations', tone: 'amber' },
  { label: 'Active jobs', value: '—', note: 'Realtime status required', tone: 'teal' },
  { label: 'Open disputes', value: '—', note: 'Support queue unavailable', tone: 'coral' },
  { label: 'Ledger balance', value: '—', note: 'Finance permission required', tone: 'ink' },
];

export async function getAdminSession(): Promise<AdminSession | null> {
  const client = getSupabaseBrowserClient();
  if (!client) return null;
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return null;
  const { data, error } = await client.from('admin_roles').select('role, permissions').eq('user_id', auth.user.id).is('revoked_at', null).maybeSingle();
  if (error || !data) return null;
  return { email: auth.user.email ?? 'Staff member', role: data.role, permissions: data.permissions ?? {} };
}

export async function getDashboardMetrics(): Promise<DashboardMetric[]> {
  try {
    const data = await invokeAdminFunction<{ metrics: DashboardMetric[] }>('admin-dashboard-metrics');
    return data.metrics;
  } catch {
    return emptyMetrics;
  }
}

export async function getRecentBookings(): Promise<BookingRow[]> {
  try {
    const data = await invokeAdminFunction<{ bookings: BookingRow[] }>('admin-bookings');
    return data.bookings;
  } catch {
    return [];
  }
}
