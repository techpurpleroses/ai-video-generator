import { useMutation, useQuery } from "@tanstack/react-query";
import {
  createCheckoutSession,
  createPortalSession,
  fetchBillingSummary,
  fetchPlans,
} from "./api";

export function usePlans() {
  return useQuery({
    queryKey: ["billing", "plans"],
    queryFn: fetchPlans,
  });
}

export function useBillingSummary() {
  return useQuery({
    queryKey: ["billing", "summary"],
    queryFn: fetchBillingSummary,
  });
}

export function useCheckout() {
  return useMutation({
    mutationFn: (payload: { plan: string; cycle: "monthly" | "yearly" }) =>
      createCheckoutSession(payload.plan, payload.cycle),
  });
}

export function useBillingPortal() {
  return useMutation({
    mutationFn: createPortalSession,
  });
}
