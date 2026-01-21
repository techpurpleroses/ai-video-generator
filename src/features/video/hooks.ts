import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createGeneration } from "./api";
import type { GeneratePayload } from "./types";

export function useCreateGeneration() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: GeneratePayload) => createGeneration(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["jobs"] });
      queryClient.invalidateQueries({ queryKey: ["credits"] });
    },
  });
}
