"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { BillingPlan } from "@/features/billing/types";

type PlanCardProps = {
  plan: BillingPlan;
  billingCycle: "monthly" | "yearly";
  highlighted?: boolean;
  onSelect: (plan: BillingPlan) => void;
};

export function PlanCard({
  plan,
  billingCycle,
  highlighted,
  onSelect,
}: PlanCardProps) {
  const price = billingCycle === "monthly" ? plan.priceMonthly : plan.priceYearly;

  return (
    <Card className={highlighted ? "border-accent shadow-md" : undefined}>
      <CardHeader>
        <CardTitle>{plan.name}</CardTitle>
        <p className="text-sm text-muted-foreground">{plan.description}</p>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <p className="text-3xl font-semibold">${price}</p>
          <p className="text-xs text-muted-foreground">
            {billingCycle === "monthly" ? "per month" : "per year"}
          </p>
        </div>
        <ul className="space-y-2 text-sm text-muted-foreground">
          {plan.features.map((feature) => (
            <li key={feature}>• {feature}</li>
          ))}
        </ul>
        <Button
          className="w-full"
          variant={highlighted ? "default" : "outline"}
          onClick={() => onSelect(plan)}
        >
          Upgrade
        </Button>
      </CardContent>
    </Card>
  );
}
