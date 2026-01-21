"use client";

import { useState } from "react";
import { PageHeader } from "@/components/common/page-header";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/common/empty-state";
import { LibraryFilters } from "@/features/library/components/library-filters";
import { LibraryItemCard } from "@/features/library/components/library-item-card";
import { LibraryModal } from "@/features/library/components/library-modal";
import { useLibrary } from "@/features/library/hooks";
import type { MediaItem } from "@/features/library/types";

export default function LibraryPage() {
  const [filters, setFilters] = useState({
    status: "all",
    type: "all",
    from: "",
    to: "",
  });
  const [selected, setSelected] = useState<MediaItem | null>(null);
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useLibrary(filters);

  const items = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <div className="space-y-8">
      <PageHeader
        title="Media library"
        description="Browse rendered outputs and manage assets."
      />

      <LibraryFilters
        status={filters.status}
        type={filters.type}
        from={filters.from}
        to={filters.to}
        onChange={(patch) => setFilters((prev) => ({ ...prev, ...patch }))}
      />

      {items.length === 0 ? (
        <EmptyState
          title="No outputs yet"
          description="Generate a video to see outputs in your library."
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {items.map((item) => (
            <LibraryItemCard key={item.id} item={item} onSelect={setSelected} />
          ))}
        </div>
      )}

      {hasNextPage ? (
        <div className="flex justify-center">
          <Button
            variant="outline"
            onClick={() => fetchNextPage()}
            disabled={isFetchingNextPage}
          >
            {isFetchingNextPage ? "Loading..." : "Load more"}
          </Button>
        </div>
      ) : null}

      <LibraryModal item={selected} onClose={() => setSelected(null)} />
    </div>
  );
}
