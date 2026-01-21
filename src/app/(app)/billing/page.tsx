"use client";

import { useState } from "react";
import { toast } from "sonner";
import { PageHeader } from "@/components/common/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useBillingPortal, useBillingSummary, useCheckout, usePlans } from "@/features/billing/hooks";
import { PlanCard } from "@/features/billing/components/plan-card";

export default function BillingPage() {
  const [cycle, setCycle] = useState<"monthly" | "yearly">("monthly");
  const { data: plans } = usePlans();
  const { data: summary } = useBillingSummary();
  const checkout = useCheckout();
  const portal = useBillingPortal();

  async function handleUpgrade(plan: string) {
    try {
      const response = await checkout.mutateAsync({ plan, cycle });
      toast.success("Redirecting to checkout...");
      window.location.href = response.url;
    } catch (error) {
      toast.error("Unable to start checkout.");
    }
  }

  async function handlePortal() {
    try {
      const response = await portal.mutateAsync();
      toast.success("Opening billing portal...");
      window.location.href = response.url;
    } catch (error) {
      toast.error("Unable to open billing portal.");
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Billing"
        description="Manage plans and billing preferences."
        actions={
          <Button variant="outline" onClick={handlePortal}>
            Manage billing
          </Button>
        }
      />

      {summary ? (
        <Card>
          <CardContent className="flex flex-wrap items-center justify-between gap-4 p-6 text-sm">
            <div>
              <p className="text-xs uppercase tracking-wide text-muted-foreground">
                Current plan
              </p>
              <p className="text-lg font-semibold">{summary.currentPlan}</p>
            </div>
            <div>
              <p className="text-xs uppercase tracking-wide text-muted-foreground">
                Renewal date
              </p>
              <p className="text-sm">{new Date(summary.renewalDate).toDateString()}</p>
            </div>
            <div>
              <p className="text-xs uppercase tracking-wide text-muted-foreground">
                Status
              </p>
              <p className="text-sm">{summary.status}</p>
            </div>
          </CardContent>
        </Card>
      ) : null}

      <div className="flex items-center gap-2 text-sm">
        <Button
          variant={cycle === "monthly" ? "default" : "outline"}
          size="sm"
          onClick={() => setCycle("monthly")}
        >
          Monthly
        </Button>
        <Button
          variant={cycle === "yearly" ? "default" : "outline"}
          size="sm"
          onClick={() => setCycle("yearly")}
        >
          Yearly
        </Button>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        {plans?.map((plan) => (
          <PlanCard
            key={plan.name}
            plan={plan}
            billingCycle={cycle}
            highlighted={plan.name === "Pro"}
            onSelect={() => handleUpgrade(plan.name)}
          />
        ))}
      </div>
    </div>
  );
}
