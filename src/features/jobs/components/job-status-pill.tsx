import { Badge } from "@/components/ui/badge";
import { JOB_STATUS_LABELS } from "@/lib/constants";
import type { JobStatus } from "@/features/jobs/types";

const statusVariant: Record<
  JobStatus,
  "default" | "accent" | "muted" | "outline" | "destructive"
> = {
  queued: "muted",
  running: "accent",
  succeeded: "default",
  failed: "destructive",
  canceled: "outline",
};

export function JobStatusPill({ status }: { status: JobStatus }) {
  return <Badge variant={statusVariant[status]}>{JOB_STATUS_LABELS[status]}</Badge>;
}
