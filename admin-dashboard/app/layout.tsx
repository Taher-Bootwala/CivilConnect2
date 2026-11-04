import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'CivilConnect Control Room',
  description: 'Operations, safety and financial administration for CivilConnect.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
