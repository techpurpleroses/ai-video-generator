import type { GenerationSettings, Job } from "@/lib/types";
import { estimateCredits } from "@/lib/credits";
import { getSupabaseUrl } from "@/lib/supabase/env";

const statusProgress: Record<string, number> = {
  queued: 0,
  running: 50,
  succeeded: 100,
  failed: 100,
  canceled: 0,
};

export function buildSettings(
  params: Record<string, unknown> | null | undefined,
  prompt: string,
  negativePrompt?: string | null
): GenerationSettings {
  const mode = typeof params?.mode === "string" ? params.mode : "text";
  return {
    mode,
    prompt,
    negativePrompt: negativePrompt ?? undefined,
    stylePreset: (params?.stylePreset as string) ?? "Cinematic",
    aspectRatio: (params?.aspectRatio as string) ?? "16:9",
    duration: (params?.duration as string) ?? "16s",
    quality: (params?.quality as string) ?? "Standard",
    cameraMovement: (params?.cameraMovement as string) ?? "Static",
    seed: (params?.seed as string) ?? undefined,
    inputImageUrl: (params?.inputImageUrl as string) ?? undefined,
  };
}

export function buildPublicFileUrl(file?: {
  bucket?: string | null;
  path?: string | null;
  is_public?: boolean | null;
}) {
  if (!file?.bucket || !file?.path || !file?.is_public) {
    return undefined;
  }
  const base = getSupabaseUrl();
  const encodedPath = file.path
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  return `${base}/storage/v1/object/public/${file.bucket}/${encodedPath}`;
}

export function mapJobRow(row: {
  id: string;
  status: string;
  created_at: string;
  updated_at: string;
  last_error?: string | null;
  generation?: {
    prompt?: string | null;
    negative_prompt?: string | null;
    params?: Record<string, unknown> | null;
    error_message?: string | null;
  } | null;
  outputs?: Array<{
    file?: {
      bucket?: string | null;
      path?: string | null;
      is_public?: boolean | null;
    } | null;
  }> | null;
}) : Job {
  const generation = row.generation ?? {};
  const params = generation.params ?? {};
  const settings = buildSettings(
    params,
    generation.prompt ?? "",
    generation.negative_prompt ?? undefined
  );

  const creditsEstimated =
    typeof params.creditsEstimated === "number"
      ? params.creditsEstimated
      : estimateCredits({
          duration: settings.duration,
          quality: settings.quality,
          aspectRatio: settings.aspectRatio,
        });

  const outputFile = row.outputs?.[0]?.file ?? undefined;
  const outputUrl = buildPublicFileUrl(outputFile);

  const logs: string[] = [];
  if (row.status) {
    logs.push(`Status: ${row.status}`);
  }
  if (row.last_error) {
    logs.push(row.last_error);
  }
  if (generation.error_message) {
    logs.push(generation.error_message);
  }

  return {
    id: row.id,
    title:
      (params.title as string) ??
      (generation.prompt?.slice(0, 48) ?? "Generation"),
    status: row.status as Job["status"],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    progress: statusProgress[row.status] ?? 0,
    creditsEstimated,
    settings,
    outputUrl,
    logs,
  };
}
