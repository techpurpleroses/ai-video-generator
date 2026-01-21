import type { GenerationSettings, Job } from "@/lib/types";

export type GeneratePayload = GenerationSettings & {
  title?: string;
};

export type GenerateResponse = {
  job: Job;
};
