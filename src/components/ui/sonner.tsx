"use client";

import { Toaster as SonnerToaster } from "sonner";

export function Toaster() {
  return (
    <SonnerToaster
      position="top-right"
      expand
      toastOptions={{
        classNames: {
          toast:
            "group toast rounded-2xl border border-border/60 bg-card text-foreground shadow-lg",
          description: "text-muted-foreground",
          actionButton:
            "bg-primary text-primary-foreground hover:opacity-90 rounded-full",
          cancelButton: "bg-secondary text-secondary-foreground rounded-full",
        },
      }}
    />
  );
}
