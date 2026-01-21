export type User = {
  id: string;
  name: string;
  email: string;
  avatarUrl?: string;
};

export type Session = {
  user: User;
  plan: "Free" | "Pro" | "Business";
};

export type JobStatus = "queued" | "running" | "succeeded" | "failed" | "canceled";

export type GenerationSettings = {
  mode: string;
  prompt: string;
  negativePrompt?: string;
  stylePreset: string;
  aspectRatio: string;
  duration: string;
  quality: string;
  cameraMovement: string;
  seed?: string;
  inputImageUrl?: string;
};

export type Job = {
  id: string;
  title: string;
  status: JobStatus;
  createdAt: string;
  updatedAt: string;
  progress: number;
  creditsEstimated: number;
  creditsCharged?: number;
  settings: GenerationSettings;
  outputUrl?: string;
  previewImage?: string;
  logs: string[];
};

export type MediaItem = {
  id: string;
  title: string;
  status: "ready" | "processing" | "failed";
  type: "text-to-video" | "image-to-video";
  createdAt: string;
  thumbnailUrl: string;
  videoUrl?: string;
  settings: GenerationSettings;
};

export type CreditsSnapshot = {
  available: number;
  reserved: number;
  holds: number;
  ledger: {
    id: string;
    createdAt: string;
    description: string;
    delta: number;
    jobId?: string;
  }[];
};

export type BillingPlan = {
  name: "Free" | "Pro" | "Business";
  priceMonthly: number;
  priceYearly: number;
  description: string;
  features: string[];
};
