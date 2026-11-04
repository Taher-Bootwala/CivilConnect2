import { EmptyState } from './empty-state';
import type { BookingRow } from '@/lib/types';

function statusClass(status: string) {
  const value = status.toLowerCase();
  if (value.includes('paid') || value.includes('active') || value.includes('approved')) return 'status status-green';
  if (value.includes('pending') || value.includes('dispatch') || value.includes('review')) return 'status status-amber';
  return 'status status-red';
}

export function BookingTable({ rows }: { rows: BookingRow[] }) {
  if (rows.length === 0) return <EmptyState title="No booking records loaded" message="Live bookings will appear here after an authorized Supabase connection is configured." />;
  return <div className="table-wrap"><table><thead><tr><th>Booking</th><th>Service</th><th>Parties</th><th>Appointment</th><th>Amount</th><th>Status</th></tr></thead><tbody>{rows.map((row) => <tr key={row.id}><td><div className="font-black">{row.id}</div></td><td>{row.service}</td><td><div>{row.customer}</div><div className="mt-1 text-[11px] text-slate-400">{row.professional}</div></td><td>{row.time}</td><td>{row.amount}</td><td><span className={statusClass(row.status)}>{row.status}</span></td></tr>)}</tbody></table></div>;
}
