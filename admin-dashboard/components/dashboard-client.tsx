'use client';

import { ArrowUpRight, CalendarClock, CircleAlert, Database, Plus, ReceiptText } from 'lucide-react';
import { useEffect, useState } from 'react';
import { BookingTable } from './data-table';
import { MetricCard } from './metric-card';
import { emptyMetrics } from '@/lib/admin-data';
import type { BookingRow, DashboardMetric } from '@/lib/types';
import { invokeAdminFunction } from '@/lib/supabase';

export function DashboardClient() {
  const [metrics, setMetrics] = useState<DashboardMetric[]>(emptyMetrics);
  const [bookings, setBookings] = useState<BookingRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      invokeAdminFunction<{ metrics: DashboardMetric[] }>('admin-dashboard-metrics'),
      invokeAdminFunction<{ bookings: BookingRow[] }>('admin-bookings'),
    ]).then(([metricResult, bookingResult]) => {
      setMetrics(metricResult.metrics);
      setBookings(bookingResult.bookings);
    }).catch(() => undefined).finally(() => setLoading(false));
  }, []);

  return <><div className="flex flex-col justify-between gap-5 md:flex-row md:items-end"><div><div className="eyebrow">Good morning, operations</div><h1 className="page-title">Keep the whole network moving.</h1><p className="mt-3 max-w-xl text-sm leading-6 text-slate-500">A single view of jobs, trust, money and the decisions that need a human eye.</p></div><div className="flex gap-2"><button className="btn btn-light"><CalendarClock size={15} /> Schedule view</button><button className="btn btn-amber"><Plus size={15} /> New configuration</button></div></div><div className="mt-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{metrics.map((metric) => <MetricCard metric={metric} key={metric.label} />)}</div><div className="mt-7 grid gap-5 xl:grid-cols-[1.35fr_.65fr]"><section className="surface"><div className="flex items-center justify-between border-b border-slate-100 px-5 py-5"><div><div className="text-base font-black">Live booking pulse</div><div className="mt-1 text-xs font-semibold text-slate-400">{loading ? 'Connecting to authorized operations data…' : 'Customer, professional and financial states stay separate.'}</div></div><a className="flex items-center gap-1 text-xs font-black text-[var(--coral)]" href="/bookings">Open monitor <ArrowUpRight size={14} /></a></div><BookingTable rows={bookings} /></section><section className="surface"><div className="border-b border-slate-100 px-5 py-5"><div className="text-base font-black">Control room signals</div><div className="mt-1 text-xs font-semibold text-slate-400">What needs attention today.</div></div><div className="space-y-3 p-5"><Signal icon={<CircleAlert size={17} />} title="Human review queue" text="Quote disputes and high-value adjustments require an authorized decision." tone="coral" /><Signal icon={<ReceiptText size={17} />} title="Immutable finance" text="Posted journals are append-only; corrections require reversals." tone="amber" /><Signal icon={<Database size={17} />} title="Data connection" text={loading ? 'Connecting to Supabase…' : metrics[0]?.value === '—' ? 'Configure Supabase and an authorized staff session.' : 'Live metrics connected.'} tone="teal" /></div></section></div><div className="mt-7 grid gap-5 md:grid-cols-3"><InfoCard number="01" title="Trust before speed" text="KYC approval, arrival evidence and start OTP protect both sides of every job." /><InfoCard number="02" title="Money with receipts" text="Cash collected, dues, earnings and withdrawable balances never get mixed." /><InfoCard number="03" title="Audit every decision" text="Every admin action carries a role, reason, timestamp and immutable record." /></div></>;
}

function Signal({ icon, title, text, tone }: { icon: React.ReactNode; title: string; text: React.ReactNode; tone: 'coral' | 'amber' | 'teal' }) { return <div className="flex gap-3 rounded-2xl bg-slate-50 p-4"><span className={`grid h-9 w-9 shrink-0 place-items-center rounded-xl ${tone === 'coral' ? 'bg-[var(--coral-soft)] text-[var(--coral)]' : tone === 'amber' ? 'bg-[var(--amber-soft)] text-amber-700' : 'bg-[var(--teal-soft)] text-[var(--teal)]'}`}>{icon}</span><div><div className="text-xs font-black">{title}</div><div className="mt-1 text-[11px] leading-5 text-slate-500">{text}</div></div></div>; }
function InfoCard({ number, title, text }: { number: string; title: string; text: string }) { return <div className="surface p-5"><div className="text-xs font-black text-[var(--coral)]">{number}</div><div className="mt-4 text-sm font-black">{title}</div><p className="mt-2 text-xs leading-5 text-slate-500">{text}</p></div>; }
