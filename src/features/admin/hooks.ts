import { useQuery } from "@tanstack/react-query";
import { fetchAdminSummary } from "./api";

export function useAdminSummary(enabled = true) {
  return useQuery({
    queryKey: ["admin", "summary"],
    queryFn: fetchAdminSummary,
    enabled,
  });
}
