export function getSupabaseUrl() {
  const direct =
    process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
  if (direct) {
    return direct;
  }
  const ref = process.env.SUPABASE_PROJECT_REF;
  if (!ref) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_PROJECT_REF.");
  }
  return `https://${ref}.supabase.co`;
}

export function getSupabaseAnonKey() {
  return (
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY
  );
}

export function getSupabaseServiceRoleKey() {
  return process.env.SUPABASE_SERVICE_ROLE_KEY;
}

export function getSupabaseProjectRef() {
  return process.env.SUPABASE_PROJECT_REF;
}
