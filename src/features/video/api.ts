import { apiFetch } from "@/lib/api/client";
import type { GeneratePayload, GenerateResponse } from "./types";

export async function createGeneration(
  payload: GeneratePayload
): Promise<GenerateResponse> {
  return apiFetch<GenerateResponse>("/api/generate", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
