import type { MediaItem } from "@/lib/types";
import { buildPublicFileUrl, buildSettings } from "./jobs";

export function mapMediaRow(row: {
  id: string;
  status: string;
  prompt?: string | null;
  negative_prompt?: string | null;
  params?: Record<string, unknown> | null;
  created_at: string;
  outputs?: Array<{
    file?: {
      bucket?: string | null;
      path?: string | null;
      is_public?: boolean | null;
    } | null;
  }> | null;
}): MediaItem {
  const params = row.params ?? {};
  const settings = buildSettings(
    params,
    row.prompt ?? "",
    row.negative_prompt ?? undefined
  );
  const outputFile = row.outputs?.[0]?.file ?? undefined;
  const mediaUrl = buildPublicFileUrl(outputFile);

  let status: MediaItem["status"] = "processing";
  if (row.status === "succeeded" && mediaUrl) {
    status = "ready";
  } else if (row.status === "failed" || row.status === "canceled") {
    status = "failed";
  }

  const type: MediaItem["type"] =
    settings.mode === "image" ? "image-to-video" : "text-to-video";

  return {
    id: row.id,
    title:
      (params.title as string) ?? (row.prompt?.slice(0, 48) ?? "Generation"),
    status,
    type,
    createdAt: row.created_at,
    thumbnailUrl: mediaUrl ?? "",
    videoUrl: mediaUrl ?? undefined,
    settings,
  };
}
