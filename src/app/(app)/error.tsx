"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";

export default function AppError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="rounded-2xl border border-border/60 bg-card p-8">
      <h2 className="text-lg font-semibold">We hit a snag</h2>
      <p className="mt-2 text-sm text-muted-foreground">
        Something went wrong while loading this section. Please try again.
      </p>
      <Button className="mt-4" onClick={reset}>
        Retry
      </Button>
    </div>
  );
}
