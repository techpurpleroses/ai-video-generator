import { useQuery } from "@tanstack/react-query";
import { fetchCredits } from "./api";

export function useCredits() {
  return useQuery({
    queryKey: ["credits"],
    queryFn: fetchCredits,
    staleTime: 15_000,
  });
}
