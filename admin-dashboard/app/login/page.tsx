import { ShieldCheck } from 'lucide-react';
import { LoginForm } from '@/components/login-form';

export default function LoginPage() {
  return <main className="grid min-h-screen place-items-center bg-[var(--canvas)] px-5 py-10"><div className="fixed left-0 top-0 h-1 w-full bg-[var(--amber)]" /><div className="absolute left-8 top-8 hidden items-center gap-2 text-xs font-black text-slate-500 sm:flex"><ShieldCheck size={17} className="text-[var(--teal)]" /> Operations with accountability</div><LoginForm /></main>;
}
