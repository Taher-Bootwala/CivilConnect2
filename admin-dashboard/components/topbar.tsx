'use client';

import { Bell, Menu, Search } from 'lucide-react';

export function Topbar({ title }: { title: string }) {
  return <header className="topbar"><div className="flex items-center gap-3"><button className="btn btn-light mobile-menu" aria-label="Open menu"><Menu size={17} /></button><div><div className="text-xs font-bold uppercase tracking-[.14em] text-slate-400">Tuesday, 27 October 2026</div><div className="mt-1 text-sm font-black">{title}</div></div></div><div className="flex items-center gap-3"><button className="btn btn-light hidden sm:inline-flex"><Search size={16} /> Search</button><button className="grid h-10 w-10 place-items-center rounded-xl border border-slate-200 bg-white text-slate-600" aria-label="Notifications"><Bell size={17} /></button><div className="hidden h-9 w-px bg-slate-200 sm:block" /><span className="hidden text-xs font-extrabold text-slate-600 sm:inline">Admin / Operations</span></div></header>;
}
