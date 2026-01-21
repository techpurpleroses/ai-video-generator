"use client";

import { useState } from "react";
import { PageHeader } from "@/components/common/page-header";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useJobs, useRetryJob, useCancelJob } from "@/features/jobs/hooks";
import { JobCard } from "@/features/jobs/components/job-card";
import { EmptyState } from "@/components/common/empty-state";

export default function JobsPage() {
  const [status, setStatus] = useState("all");
  const { data: jobs, isLoading } = useJobs(status);
  const retryJob = useRetryJob();
  const cancelJob = useCancelJob();

  return (
    <div className="space-y-8">
      <PageHeader
        title="Jobs"
        description="Track renders, retry failures, and audit status."
        actions={
          <Select value={status} onValueChange={setStatus}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Filter" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="queued">Queued</SelectItem>
              <SelectItem value="running">Running</SelectItem>
              <SelectItem value="succeeded">Succeeded</SelectItem>
              <SelectItem value="failed">Failed</SelectItem>
              <SelectItem value="canceled">Canceled</SelectItem>
            </SelectContent>
          </Select>
        }
      />

      <div className="space-y-4">
        {isLoading ? (
          <div className="text-sm text-muted-foreground">Loading jobs...</div>
        ) : null}
        {!isLoading && (!jobs || jobs.length === 0) ? (
          <EmptyState
            title="No jobs found"
            description="Try generating a video to see it here."
          />
        ) : null}
        {jobs?.map((job) => (
          <JobCard
            key={job.id}
            job={job}
            onRetry={(id) => retryJob.mutate(id)}
            onCancel={(id) => cancelJob.mutate(id)}
          />
        ))}
      </div>
    </div>
  );
}
