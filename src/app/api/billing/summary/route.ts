import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";

function normalizePlanName(value?: string | null) {
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
    const { admin, orgId } = await requireUserContext();

    const { data: subscription } = await admin
      .from("subscriptions")
      .select("plan_code, status, period_ends, created_at")
      .eq("org_id", orgId)
      .in("status", ["active", "trialing", "past_due", "canceled"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    let planName = "Free";

    if (subscription?.plan_code) {
      const { data: planRow } = await admin
        .from("plan_catalog")
        .select("name, plan_code")
        .eq("plan_code", subscription.plan_code)
        .maybeSingle();

      planName = normalizePlanName(planRow?.name ?? subscription.plan_code);
    }

    return NextResponse.json({
      currentPlan: planName,
      renewalDate: subscription?.period_ends ?? subscription?.created_at ?? new Date().toISOString(),
      status: subscription?.status ?? "active",
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to load billing summary." }, { status: 500 });
  }
}
