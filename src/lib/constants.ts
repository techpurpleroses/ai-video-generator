export const JOB_STATUSES = [
  "queued",
  "running",
  "succeeded",
  "failed",
  "canceled",
] as const;

export const JOB_STATUS_LABELS: Record<(typeof JOB_STATUSES)[number], string> = {
  queued: "Queued",
  running: "Running",
  succeeded: "Succeeded",
  failed: "Failed",
  canceled: "Canceled",
};

export const PLAN_LABELS = ["Free", "Pro", "Business"] as const;

export const CREDIT_UNITS = {
  seconds: "seconds",
  frames: "frames",
  tokens: "tokens",
} as const;
