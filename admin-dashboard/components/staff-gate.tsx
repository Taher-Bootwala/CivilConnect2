'use client';

import { useEffect, useState, type ReactNode } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { getAdminSession } from '@/lib/admin-data';

export function StaffGate({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let mounted = true;
    getAdminSession().then((session) => {
      if (!mounted) return;
      if (!session) router.replace(`/login?next=${encodeURIComponent(pathname)}`);
      else setReady(true);
    });
    return () => { mounted = false; };
  }, [pathname, router]);

  if (!ready) return <div className="grid min-h-screen place-items-center bg-[var(--canvas)]"><div className="text-xs font-black uppercase tracking-[.16em] text-slate-400">Checking staff access…</div></div>;
  return <>{children}</>;
}
