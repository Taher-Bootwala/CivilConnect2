import { createClient, type SupabaseClient } from '@supabase/supabase-js';

let browserClient: SupabaseClient | undefined;

export function getSupabaseBrowserClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  browserClient ??= createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true } });
  return browserClient;
}

export function functionsUrl() {
  return process.env.NEXT_PUBLIC_FUNCTIONS_URL ?? '';
}

export async function invokeAdminFunction<T>(name: string, body?: Record<string, unknown>): Promise<T> {
  const client = getSupabaseBrowserClient();
  if (!client) throw new Error('Supabase is not configured for this dashboard.');
  const { data, error } = await client.functions.invoke(name, { body });
  if (error) throw error;
  return data as T;
}
