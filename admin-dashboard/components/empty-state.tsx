import { DatabaseZap } from 'lucide-react';

export function EmptyState({ title = 'No live records yet', message = 'Connect the admin dashboard to your Supabase project to load authorized data.' }: { title?: string; message?: string }) {
  return <div className="empty-state"><div className="empty-icon"><DatabaseZap size={21} /></div><div className="text-sm font-black text-slate-700">{title}</div><p className="mx-auto mt-2 max-w-md text-xs leading-5">{message}</p></div>;
}
