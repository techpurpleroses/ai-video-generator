"use client";

import { useRouter } from "next/navigation";
import { useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { PageHeader } from "@/components/common/page-header";
import { JobStatusPill } from "@/features/jobs/components/job-status-pill";
import { useJob } from "@/features/jobs/hooks";
import { useGeneratorStore } from "@/features/video/store";
import { routes } from "@/lib/routes";

export default function JobDetailPage() {
  const params = useParams();
  const jobId = String(params.id);
  const router = useRouter();
  const { data: job, isLoading } = useJob(jobId);
  const { setDraft } = useGeneratorStore();

  if (isLoading) {
    return <div className="text-sm text-muted-foreground">Loading job...</div>;
  }

  if (!job) {
    return <div className="text-sm text-muted-foreground">Job not found.</div>;
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={job.title}
        description={`Job ID: ${job.id}`}
        actions={<JobStatusPill status={job.status} />}
      />

      <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
        <Card>
          <CardContent className="space-y-6 p-6">
            <div>
              <p className="text-xs uppercase tracking-wide text-muted-foreground">
                Input parameters
              </p>
              <p className="mt-2 text-sm text-foreground">{job.settings.prompt}</p>
            </div>
            {job.status === "succeeded" ? (
              <div>
                <p className="text-xs uppercase tracking-wide text-muted-foreground">
                  Output preview
                </p>
                <div className="mt-2 h-48 w-full rounded-2xl bg-muted/60" />
              </div>
            ) : null}
            <div className="grid gap-4 text-sm text-muted-foreground md:grid-cols-2">
              <div>
                <p>Aspect ratio: {job.settings.aspectRatio}</p>
                <p>Duration: {job.settings.duration}</p>
                <p>Quality: {job.settings.quality}</p>
              </div>
              <div>
                <p>Style: {job.settings.stylePreset}</p>
                <p>Camera: {job.settings.cameraMovement}</p>
                <p>Seed: {job.settings.seed ?? "Auto"}</p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <Button disabled={job.status !== "succeeded"}>
                Download output
              </Button>
              <Button variant="outline" disabled={job.status !== "succeeded"}>
                Open preview
              </Button>
            </div>
          </CardContent>
        </Card>
        <div className="space-y-4">
          <Card>
            <CardContent className="space-y-2 p-6 text-sm text-muted-foreground">
              <p className="text-xs uppercase tracking-wide">Cost</p>
              <p className="text-2xl font-semibold text-foreground">
                {job.creditsCharged ?? job.creditsEstimated} credits
              </p>
              <p>Charged when render completes.</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="space-y-3 p-6 text-sm text-muted-foreground">
              <p className="text-xs uppercase tracking-wide">Logs</p>
              <ul className="space-y-2">
                {job.logs.map((log, index) => (
                  <li key={`${log}-${index}`}>{log}</li>
                ))}
              </ul>
            </CardContent>
          </Card>
          <Button
            variant="outline"
            onClick={() => {
              setDraft(job.settings);
              router.push(routes.generate);
            }}
          >
            Create variation
          </Button>
        </div>
      </div>
    </div>
  );
}
