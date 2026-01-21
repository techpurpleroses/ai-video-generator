import { apiFetch } from "@/lib/api/client";
import type { Job } from "./types";

export async function fetchJobs(status?: string): Promise<Job[]> {
  const query = status ? `?status=${encodeURIComponent(status)}` : "";
  return apiFetch<Job[]>(`/api/jobs${query}`);
}

export async function fetchJob(id: string): Promise<Job> {
  return apiFetch<Job>(`/api/jobs/${id}`);
}

export async function retryJob(id: string): Promise<Job> {
  return apiFetch<Job>(`/api/jobs/${id}/retry`, { method: "POST" });
}

export async function cancelJob(id: string): Promise<Job> {
  return apiFetch<Job>(`/api/jobs/${id}/cancel`, { method: "POST" });
}
