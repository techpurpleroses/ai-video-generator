"use client";

import { PageHeader } from "@/components/common/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useJobs } from "@/features/jobs/hooks";
import { useCredits } from "@/features/credits/hooks";
import { JobStatusPill } from "@/features/jobs/components/job-status-pill";
import { EmptyState } from "@/components/common/empty-state";

export default function DashboardPage() {
  const { data: jobs } = useJobs();
  const { data: credits } = useCredits();

  return (
    <div className="space-y-8">
      <PageHeader
        title="Dashboard"
        description="Overview of recent activity and usage."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>Credits available</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold">{credits?.available ?? "--"}</p>
            <p className="text-xs text-muted-foreground">Includes reserved holds.</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Active jobs</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold">
              {jobs?.filter((job) => job.status === "running")?.length ?? 0}
            </p>
            <p className="text-xs text-muted-foreground">Currently rendering.</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Completed</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-semibold">
              {jobs?.filter((job) => job.status === "succeeded")?.length ?? 0}
            </p>
            <p className="text-xs text-muted-foreground">Last 24 hours.</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Recent jobs</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {!jobs || jobs.length === 0 ? (
            <EmptyState
              title="No jobs yet"
              description="Generate your first clip to populate the dashboard."
            />
          ) : (
            jobs.slice(0, 4).map((job) => (
              <div
                key={job.id}
                className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border/60 p-4"
              >
                <div>
                  <p className="text-sm font-semibold">{job.title}</p>
                  <p className="text-xs text-muted-foreground">
                    {new Date(job.createdAt).toLocaleString()}
                  </p>
                </div>
                <JobStatusPill status={job.status} />
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
