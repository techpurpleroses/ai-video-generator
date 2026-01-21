import { apiFetch } from "@/lib/api/client";
import type { MediaItem } from "./types";

export type LibraryFilters = {
  status?: string;
  type?: string;
  from?: string;
  to?: string;
  cursor?: string | null;
};

export type LibraryResponse = {
  items: MediaItem[];
  nextCursor: string | null;
};

export async function fetchLibrary(filters: LibraryFilters): Promise<LibraryResponse> {
  const params = new URLSearchParams();
  if (filters.status) params.set("status", filters.status);
  if (filters.type) params.set("type", filters.type);
  if (filters.from) params.set("from", filters.from);
  if (filters.to) params.set("to", filters.to);
  if (filters.cursor) params.set("cursor", filters.cursor);
  return apiFetch<LibraryResponse>(`/api/library?${params.toString()}`);
}
