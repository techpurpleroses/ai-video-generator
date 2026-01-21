"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { JobStatusPill } from "./job-status-pill";
import type { Job } from "@/features/jobs/types";
import { routes } from "@/lib/routes";

type JobCardProps = {
  job: Job;
  onRetry?: (id: string) => void;
  onCancel?: (id: string) => void;
};

export function JobCard({ job, onRetry, onCancel }: JobCardProps) {
  return (
    <Card>
      <CardContent className="space-y-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <Link
              href={`${routes.jobs}/${job.id}`}
              className="text-base font-semibold text-foreground hover:underline"
            >
              {job.title}
            </Link>
            <p className="text-xs text-muted-foreground">
              {new Date(job.createdAt).toLocaleString()}
            </p>
          </div>
          <JobStatusPill status={job.status} />
        </div>
        <Progress value={job.progress} />
        <div className="flex flex-wrap items-center justify-between gap-3 text-xs text-muted-foreground">
          <span>Credits: {job.creditsEstimated}</span>
          <span>Updated {new Date(job.updatedAt).toLocaleTimeString()}</span>
        </div>
        <div className="flex flex-wrap gap-2">
          {job.status === "failed" ? (
            <Button size="sm" onClick={() => onRetry?.(job.id)}>
              Retry
            </Button>
          ) : null}
          {job.status === "running" || job.status === "queued" ? (
            <Button variant="outline" size="sm" onClick={() => onCancel?.(job.id)}>
              Cancel
            </Button>
          ) : null}
        </div>
      </CardContent>
    </Card>
  );
}
