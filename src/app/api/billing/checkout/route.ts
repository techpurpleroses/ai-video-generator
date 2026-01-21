import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";
import { getStripeClient } from "@/lib/stripe";

function normalizePlanName(value?: string | null) {
  const normalized = (value ?? "").toLowerCase();
  if (normalized.includes("pro")) {
    return "pro";
  }
  if (normalized.includes("business") || normalized.includes("enterprise")) {
    return "business";
  }
  return "free";
}

export async function POST(request: Request) {
  try {
    const payload = (await request.json()) as {
      plan?: string;
      cycle?: "monthly" | "yearly";
    };

    if (!payload.plan) {
      return NextResponse.json(
        { message: "Plan is required." },
        { status: 400 }
      );
    }

    const { admin, orgId, user, role } = await requireUserContext();
    const stripe = getStripeClient();

    if (!stripe) {
      return NextResponse.json(
        { message: "Stripe is not configured." },
        { status: 501 }
      );
    }

    if (role && !["owner", "admin"].includes(role)) {
      return NextResponse.json(
        { message: "Insufficient permissions." },
        { status: 403 }
      );
    }
    const billingCycle = payload.cycle ?? "monthly";
    const origin =
      request.headers.get("origin") ?? process.env.NEXT_PUBLIC_SITE_URL ?? "";

    if (!origin) {
      return NextResponse.json(
        { message: "Missing site URL for checkout." },
        { status: 400 }
      );
    }

    const { data: org } = await admin
      .from("organizations")
      .select("id, name, stripe_customer_id")
      .eq("id", orgId)
      .maybeSingle();

    if (!org) {
      return NextResponse.json({ message: "Organization not found." }, { status: 404 });
    }

    const { data: planRows } = await admin
      .from("plan_catalog")
      .select("plan_code, name")
      .eq("is_active", true);

    const desired = normalizePlanName(payload.plan);
    const planRow =
      planRows?.find(
        (plan) => normalizePlanName(plan.name ?? plan.plan_code) === desired
      ) ?? null;

    if (!planRow) {
      return NextResponse.json({ message: "Plan not found." }, { status: 404 });
    }

    const { data: priceRow } = await admin
      .from("plan_prices")
      .select("stripe_price_id")
      .eq("plan_code", planRow.plan_code)
      .eq("billing_cycle", billingCycle)
      .eq("is_active", true)
      .maybeSingle();

    if (!priceRow?.stripe_price_id) {
      return NextResponse.json(
        { message: "Stripe price not configured." },
        { status: 400 }
      );
    }

    let customerId = org.stripe_customer_id ?? null;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email ?? undefined,
        name: org.name ?? undefined,
      });
      customerId = customer.id;
      await admin
        .from("organizations")
        .update({ stripe_customer_id: customerId })
        .eq("id", org.id);
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      line_items: [{ price: priceRow.stripe_price_id, quantity: 1 }],
      success_url: `${origin}/billing?checkout=success`,
      cancel_url: `${origin}/billing?checkout=cancel`,
      metadata: {
        org_id: orgId,
        plan_code: planRow.plan_code,
        billing_cycle: billingCycle,
      },
      subscription_data: {
        metadata: {
          org_id: orgId,
          plan_code: planRow.plan_code,
          billing_cycle: billingCycle,
        },
      },
    });

    return NextResponse.json({ url: session.url });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json(
      { message: "Unable to start checkout." },
      { status: 500 }
    );
  }
}
