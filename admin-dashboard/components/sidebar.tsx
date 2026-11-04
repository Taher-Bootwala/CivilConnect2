'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Activity, BarChart3, BriefcaseBusiness, CircleDollarSign, FileCheck2, LayoutDashboard, LifeBuoy, Settings, ShieldCheck, SlidersHorizontal, Users } from 'lucide-react';

const sections = [
  { label: 'Command centre', items: [{ href: '/', label: 'Overview', icon: LayoutDashboard }, { href: '/bookings', label: 'Live bookings', icon: Activity }, { href: '/professionals', label: 'Professionals', icon: BriefcaseBusiness }, { href: '/customers', label: 'Customers', icon: Users }] },
  { label: 'Trust & money', items: [{ href: '/kyc', label: 'KYC review', icon: FileCheck2 }, { href: '/disputes', label: 'Disputes & support', icon: LifeBuoy }, { href: '/finance', label: 'Finance & ledger', icon: CircleDollarSign }] },
  { label: 'Configuration', items: [{ href: '/services', label: 'Services & pricing', icon: SlidersHorizontal }, { href: '/reports', label: 'Reports', icon: BarChart3 }, { href: '/settings', label: 'Settings', icon: Settings }] },
];

export function Sidebar() {
  const pathname = usePathname();
  return <aside className="sidebar"><div className="flex items-center gap-3 px-2"><div className="brand-mark">C</div><div><div className="text-sm font-black tracking-tight">CivilConnect</div><div className="text-[10px] font-bold uppercase tracking-[.18em] text-slate-400">Control room</div></div></div><nav className="flex-1">{sections.map((section) => <div className="nav-section" key={section.label}><div className="nav-label">{section.label}</div>{section.items.map((item) => { const Icon = item.icon; const active = item.href === '/' ? pathname === '/' : pathname.startsWith(item.href); return <Link className={`nav-item ${active ? 'active' : ''}`} href={item.href} key={item.href}><Icon size={17} strokeWidth={2.3} /><span>{item.label}</span></Link>; })}</div>)}</nav><div className="mt-8 rounded-2xl border border-white/10 bg-white/5 p-4"><div className="mb-2 flex items-center gap-2 text-xs font-extrabold"><ShieldCheck size={15} className="text-amber-300" /> Safety first</div><p className="m-0 text-[11px] leading-5 text-slate-400">Every financial adjustment and KYC decision is audited.</p></div><div className="mt-4 flex items-center gap-3 border-t border-white/10 px-2 pt-4"><div className="grid h-8 w-8 place-items-center rounded-full bg-amber-300 text-xs font-black text-slate-900">A</div><div><div className="text-xs font-extrabold">Operations admin</div><div className="text-[10px] text-slate-400">Least-privilege access</div></div></div></aside>;
}
