import { NextResponse } from "next/server";
import type { BillingPlan } from "@/lib/types";
import { HttpError, requireUserContext } from "@/lib/supabase/context";

function normalizePlanName(value?: string | null): BillingPlan["name"] {
  const normalized = (value ?? "").toLowerCase();
  if (normalized.includes("pro")) {
    return "Pro";
  }
  if (normalized.includes("business") || normalized.includes("enterprise")) {
    return "Business";
  }
  return "Free";
}

export async function GET() {
  try {
    const { admin } = await requireUserContext();

    const { data: planRows } = await admin
      .from("plan_catalog")
      .select("plan_code, name, notes, is_active")
      .eq("is_active", true);

    const { data: priceRows } = await admin
      .from("plan_prices")
      .select("plan_code, billing_cycle, price_cents, currency, is_active")
      .eq("is_active", true);

    const { data: featureRows } = await admin
      .from("plan_features")
      .select("plan_code, feature:feature_catalog(description), enabled")
      .eq("enabled", true);

    const featureMap = new Map<string, string[]>();
    (featureRows ?? []).forEach((row) => {
      const description = (row.feature as { description?: string } | null)
        ?.description;
      if (!description) {
        return;
      }
      const list = featureMap.get(row.plan_code) ?? [];
      list.push(description);
      featureMap.set(row.plan_code, list);
    });

    const plans: BillingPlan[] =
      planRows?.map((plan) => {
        const prices = (priceRows ?? []).filter(
          (price) => price.plan_code === plan.plan_code
        );
        const monthly = prices.find((price) => price.billing_cycle === "monthly");
        const yearly = prices.find((price) => price.billing_cycle === "yearly");

        return {
          name: normalizePlanName(plan.name ?? plan.plan_code),
          priceMonthly: monthly ? Math.round(monthly.price_cents / 100) : 0,
          priceYearly: yearly ? Math.round(yearly.price_cents / 100) : 0,
          description: plan.notes ?? "",
          features: featureMap.get(plan.plan_code) ?? [],
        };
      }) ?? [];

    return NextResponse.json(plans);
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to load plans." }, { status: 500 });
  }
}
