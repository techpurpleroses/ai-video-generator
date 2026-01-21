import { apiFetch } from "@/lib/api/client";

export async function fetchAdminSummary(): Promise<{
  users: number;
  jobs: number;
  usageSeconds: number;
  failures: number;
}> {
  return apiFetch("/api/admin/summary");
}
