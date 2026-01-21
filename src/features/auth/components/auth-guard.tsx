"use client";

import type { ReactNode } from "react";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { routes } from "@/lib/routes";
import { useSession } from "@/features/auth/hooks";
import { Skeleton } from "@/components/ui/skeleton";

export function AuthGuard({ children }: { children: ReactNode }) {
  const router = useRouter();
  const { data, isLoading } = useSession();

  useEffect(() => {
    if (!isLoading && !data?.session) {
      router.replace(routes.login);
    }
  }, [data, isLoading, router]);

  if (isLoading || !data?.session) {
    return (
      <div className="p-6">
        <div className="space-y-3">
          <Skeleton className="h-6 w-48" />
          <Skeleton className="h-4 w-80" />
          <Skeleton className="h-24 w-full" />
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
