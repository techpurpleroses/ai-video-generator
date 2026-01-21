"use client";

import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { JobStatusPill } from "@/features/jobs/components/job-status-pill";
import { useJobs } from "@/features/jobs/hooks";
import { routes } from "@/lib/routes";

export function JobQueuePanel() {
  const { data } = useJobs();
  const jobs = data?.slice(0, 4) ?? [];

  return (
    <Card className="sticky top-24">
      <CardHeader>
        <CardTitle>Job queue</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {jobs.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            No jobs yet. Generate your first video to see it here.
          </p>
        ) : null}
        {jobs.map((job) => (
          <div key={job.id} className="space-y-2">
            <div className="flex items-center justify-between gap-2">
              <Link
                href={`${routes.jobs}/${job.id}`}
                className="text-sm font-semibold hover:underline"
              >
                {job.title}
              </Link>
              <JobStatusPill status={job.status} />
            </div>
            <Progress value={job.progress} />
            <p className="text-xs text-muted-foreground">
              Updated {new Date(job.updatedAt).toLocaleTimeString()}
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
