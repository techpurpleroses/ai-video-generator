"use client";

import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import type { MediaItem } from "@/features/library/types";

type LibraryModalProps = {
  item: MediaItem | null;
  onClose: () => void;
};

export function LibraryModal({ item, onClose }: LibraryModalProps) {
  return (
    <Dialog open={!!item} onOpenChange={(open) => (!open ? onClose() : null)}>
      <DialogContent className="max-w-2xl">
        {item ? (
          <>
            <DialogHeader>
              <DialogTitle>{item.title}</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <div className="h-56 w-full rounded-2xl bg-muted/60" />
              <div className="grid gap-3 text-sm text-muted-foreground md:grid-cols-2">
                <div>
                  <p className="text-xs uppercase tracking-wide">Prompt</p>
                  <p className="text-foreground">{item.settings.prompt}</p>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wide">Settings</p>
                  <p>
                    {item.settings.aspectRatio} · {item.settings.duration} ·{" "}
                    {item.settings.quality}
                  </p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button>Download</Button>
                <Button variant="outline">Copy share link</Button>
                <Button variant="destructive">Delete</Button>
              </div>
            </div>
          </>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}
