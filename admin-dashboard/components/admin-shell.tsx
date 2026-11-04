import type { ReactNode } from 'react';
import { Sidebar } from './sidebar';
import { StaffGate } from './staff-gate';
import { Topbar } from './topbar';

export function AdminShell({ children, title = 'Operations overview' }: { children: ReactNode; title?: string }) {
  return <StaffGate><div className="app-grid"><Sidebar /><div className="main-area"><Topbar title={title} /><main className="content">{children}</main></div></div></StaffGate>;
}
