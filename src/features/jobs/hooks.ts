import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { cancelJob, fetchJob, fetchJobs, retryJob } from "./api";
import type { Job } from "./types"; // adjust if your Job type lives elsewhere

export function useJobs(status?: string) {
  return useQuery({
    queryKey: ["jobs", status ?? "all"],
    queryFn: () => fetchJobs(status),
    refetchInterval: (query) => {
      const data = query.state.data as Job[] | undefined;
      if (!Array.isArray(data)) return false;
      return data.some((job) => job.status === "running") ? 5000 : false;
    },
  });
}

export function useJob(id: string) {
  return useQuery({
    queryKey: ["job", id],
    queryFn: () => fetchJob(id),
    refetchInterval: (query) => {
      const job = query.state.data as Job | undefined;
      return job?.status === "running" ? 4000 : false;
    },
  });
}

export function useRetryJob() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => retryJob(id),
    onSuccess: (job) => {
      queryClient.invalidateQueries({ queryKey: ["jobs"] });
      queryClient.setQueryData(["job", job.id], job);
    },
  });
}

export function useCancelJob() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => cancelJob(id),
    onSuccess: (job) => {
      queryClient.invalidateQueries({ queryKey: ["jobs"] });
      queryClient.setQueryData(["job", job.id], job);
    },
  });
}
