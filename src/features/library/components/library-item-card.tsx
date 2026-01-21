"use client";

import { Card, CardContent } from "@/components/ui/card";
import type { MediaItem } from "@/features/library/types";

type LibraryItemCardProps = {
  item: MediaItem;
  onSelect: (item: MediaItem) => void;
};

export function LibraryItemCard({ item, onSelect }: LibraryItemCardProps) {
  return (
    <Card
      className="cursor-pointer transition hover:-translate-y-1 hover:shadow-md"
      onClick={() => onSelect(item)}
      role="button"
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === "Enter") {
          onSelect(item);
        }
      }}
    >
      <CardContent className="space-y-3 p-4">
        <div className="h-40 w-full rounded-xl bg-muted/60" />
        <div>
          <p className="text-sm font-semibold">{item.title}</p>
          <p className="text-xs text-muted-foreground">
            {item.type} · {item.status}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
