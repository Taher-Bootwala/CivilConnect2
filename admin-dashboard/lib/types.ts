export type AdminRole = 'admin' | 'support' | 'finance' | 'operations';

export type AdminSession = {
  email: string;
  role: AdminRole;
  permissions: Record<string, unknown>;
};

export type DashboardMetric = {
  label: string;
  value: string;
  note: string;
  tone: 'amber' | 'teal' | 'coral' | 'ink';
};

export type BookingRow = {
  id: string;
  service: string;
  customer: string;
  professional: string;
  status: string;
  amount: string;
  time: string;
};
