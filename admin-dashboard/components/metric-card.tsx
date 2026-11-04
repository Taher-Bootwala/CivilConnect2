import { ArrowUpRight, CircleDollarSign, ClipboardList, ShieldAlert, Users } from 'lucide-react';
import type { CSSProperties } from 'react';
import type { DashboardMetric } from '@/lib/types';

const icons = { amber: ClipboardList, teal: Users, coral: ShieldAlert, ink: CircleDollarSign };

export function MetricCard({ metric }: { metric: DashboardMetric }) {
  const Icon = icons[metric.tone];
  return <div className="surface metric-card" style={{ '--metric-color': metric.tone === 'amber' ? 'var(--amber-soft)' : metric.tone === 'teal' ? 'var(--teal-soft)' : metric.tone === 'coral' ? 'var(--coral-soft)' : '#edf1f5' } as CSSProperties}><div className="relative z-10 flex items-start justify-between"><span className="text-xs font-extrabold text-slate-500">{metric.label}</span><span className="rounded-xl bg-slate-50 p-2 text-slate-600"><Icon size={16} /></span></div><div className="relative z-10 metric-value">{metric.value}</div><div className="relative z-10 metric-note flex items-center gap-1">{metric.note}<ArrowUpRight size={13} /></div></div>;
}
