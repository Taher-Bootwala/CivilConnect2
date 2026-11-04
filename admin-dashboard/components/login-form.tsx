'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowRight, LockKeyhole, ShieldCheck } from 'lucide-react';
import { getSupabaseBrowserClient } from '@/lib/supabase';

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const client = getSupabaseBrowserClient();
    if (!client) { setMessage('Configure the Supabase environment before signing in.'); return; }
    setBusy(true); setMessage('');
    const { error } = await client.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) { setMessage(error.message); return; }
    router.push('/');
    router.refresh();
  }

  return <form onSubmit={submit} className="surface w-full max-w-md p-8"><div className="mb-7 flex items-center gap-3"><div className="brand-mark">C</div><div><div className="font-black tracking-tight">CivilConnect</div><div className="text-[10px] font-extrabold uppercase tracking-[.18em] text-slate-400">Secure admin access</div></div></div><h1 className="m-0 text-3xl font-black tracking-[-.06em]">Welcome back.</h1><p className="mt-2 text-sm leading-6 text-slate-500">Sign in with an authorized staff account. Permissions are enforced by Supabase, not by this screen.</p><div className="mt-7"><label className="form-label" htmlFor="email">Work email</label><input className="form-input" id="email" type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="admin@civilconnect.in" required /></div><div className="mt-4"><label className="form-label" htmlFor="password">Password</label><input className="form-input" id="password" type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Your password" required /></div>{message && <div className="mt-4 rounded-xl bg-rose-50 p-3 text-xs font-bold leading-5 text-rose-700">{message}</div>}<button className="btn btn-dark mt-6 w-full" disabled={busy}>{busy ? 'Checking access…' : 'Enter control room'} <ArrowRight size={16} /></button><div className="mt-6 flex items-start gap-2 border-t border-slate-100 pt-5 text-[11px] leading-5 text-slate-400"><LockKeyhole size={15} className="mt-0.5 shrink-0" /> Financial, KYC and audit actions require their assigned database role.</div></form>;
}
