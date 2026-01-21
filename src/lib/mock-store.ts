import { estimateCredits } from "@/lib/credits";
import type { CreditsSnapshot, GenerationSettings, Job, MediaItem } from "@/lib/types";

type MockStore = {
  jobs: Job[];
  library: MediaItem[];
  credits: CreditsSnapshot;
};

const baseSettings: GenerationSettings = {
  mode: "text",
  prompt: "Golden hour skyline with drifting drones.",
  negativePrompt: "blurry, low detail",
  stylePreset: "Cinematic",
  aspectRatio: "16:9",
  duration: "16s",
  quality: "Standard",
  cameraMovement: "Dolly in",
  seed: "1842",
};

function createMockStore(): MockStore {
  const jobTemplates: Job[] = [
    {
      id: "job_01",
      title: "Neon skyline loop",
      status: "running",
      createdAt: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
      updatedAt: new Date().toISOString(),
      progress: 62,
      creditsEstimated: estimateCredits({
        duration: "16s",
        quality: "Standard",
        aspectRatio: "16:9",
      }),
      settings: { ...baseSettings },
      logs: [
        "Queued at 12:04 PM",
        "Model allocated: gen-3",
        "Sampling frames (24/48)",
      ],
    },
    {
      id: "job_02",
      title: "Studio product spin",
      status: "succeeded",
      createdAt: new Date(Date.now() - 1000 * 60 * 65).toISOString(),
      updatedAt: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
      progress: 100,
      creditsEstimated: estimateCredits({
        duration: "8s",
        quality: "Ultra",
        aspectRatio: "1:1",
      }),
      creditsCharged: 28,
      settings: {
        ...baseSettings,
        prompt: "Luxury watch spinning in soft studio light.",
        aspectRatio: "1:1",
        duration: "8s",
        quality: "Ultra",
        cameraMovement: "Orbit",
      },
      outputUrl: "/mock/video-1.mp4",
      previewImage: "/mock/preview-1.jpg",
      logs: ["Completed render in 4m 12s", "Output stored"],
    },
    {
      id: "job_03",
      title: "City time-lapse",
      status: "queued",
      createdAt: new Date(Date.now() - 1000 * 60 * 4).toISOString(),
      updatedAt: new Date().toISOString(),
      progress: 0,
      creditsEstimated: estimateCredits({
        duration: "32s",
        quality: "Standard",
        aspectRatio: "16:9",
      }),
      settings: {
        ...baseSettings,
        prompt: "Time-lapse of a bustling city street at night.",
        duration: "32s",
      },
      logs: ["Waiting for GPU capacity"],
    },
  ];

  const library: MediaItem[] = [
    {
      id: "lib_01",
      title: "Golden hour skyline",
      status: "ready",
      type: "text-to-video",
      createdAt: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
      thumbnailUrl: "/mock/thumb-1.jpg",
      videoUrl: "/mock/video-1.mp4",
      settings: { ...baseSettings },
    },
    {
      id: "lib_02",
      title: "Portrait lighting study",
      status: "processing",
      type: "image-to-video",
      createdAt: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
      thumbnailUrl: "/mock/thumb-2.jpg",
      settings: {
        ...baseSettings,
        mode: "image",
        prompt: "Studio portrait lighting, soft falloff",
        cameraMovement: "Static",
      },
    },
    {
      id: "lib_03",
      title: "Ocean drone pass",
      status: "failed",
      type: "text-to-video",
      createdAt: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
      thumbnailUrl: "/mock/thumb-3.jpg",
      settings: {
        ...baseSettings,
        prompt: "Drone sweeping over ocean cliffs",
      },
    },
  ];

  const credits: CreditsSnapshot = {
    available: 128,
    reserved: 24,
    holds: 12,
    ledger: [
      {
        id: "ledger_01",
        createdAt: new Date(Date.now() - 1000 * 60 * 90).toISOString(),
        description: "Job completed: Studio product spin",
        delta: -28,
        jobId: "job_02",
      },
      {
        id: "ledger_02",
        createdAt: new Date(Date.now() - 1000 * 60 * 180).toISOString(),
        description: "Weekly plan refresh",
        delta: 200,
      },
      {
        id: "ledger_03",
        createdAt: new Date(Date.now() - 1000 * 60 * 210).toISOString(),
        description: "Job reserved: Neon skyline loop",
        delta: -12,
        jobId: "job_01",
      },
    ],
  };

  return { jobs: jobTemplates, library, credits };
}

function getGlobalStore() {
  const globalForMock = globalThis as typeof globalThis & {
    __mockStore?: MockStore;
  };
  if (!globalForMock.__mockStore) {
    globalForMock.__mockStore = createMockStore();
  }
  return globalForMock.__mockStore;
}

export function getMockStore() {
  return getGlobalStore();
}
