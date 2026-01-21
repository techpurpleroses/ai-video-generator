import { apiFetch } from "@/lib/api/client";
import type { BillingPlan } from "./types";

export async function fetchPlans(): Promise<BillingPlan[]> {
  return apiFetch<BillingPlan[]>("/api/billing/plans");
}

export async function fetchBillingSummary(): Promise<{
  currentPlan: string;
  renewalDate: string;
  status: string;
}> {
  return apiFetch<{ currentPlan: string; renewalDate: string; status: string }>(
    "/api/billing/summary"
  );
}

export async function createCheckoutSession(
  plan: string,
  cycle: "monthly" | "yearly"
) {
  return apiFetch<{ url: string }>("/api/billing/checkout", {
    method: "POST",
    body: JSON.stringify({ plan, cycle }),
  });
}

export async function createPortalSession() {
  return apiFetch<{ url: string }>("/api/billing/portal", {
    method: "POST",
  });
}
