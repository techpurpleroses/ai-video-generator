import { apiFetch } from "@/lib/api/client";
import type { CreditsSnapshot } from "./types";

export async function fetchCredits(): Promise<CreditsSnapshot> {
  return apiFetch<CreditsSnapshot>("/api/credits");
}
