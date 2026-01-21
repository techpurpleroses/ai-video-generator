import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";
import { getStripeClient } from "@/lib/stripe";

export async function POST(request: Request) {
  try {
    const { admin, orgId, role } = await requireUserContext();
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
    const origin =
      request.headers.get("origin") ?? process.env.NEXT_PUBLIC_SITE_URL ?? "";

    if (!origin) {
      return NextResponse.json(
        { message: "Missing site URL for portal." },
        { status: 400 }
      );
    }

    const { data: org } = await admin
      .from("organizations")
      .select("stripe_customer_id")
      .eq("id", orgId)
      .maybeSingle();

    if (!org?.stripe_customer_id) {
      return NextResponse.json(
        { message: "Stripe customer not found." },
        { status: 400 }
      );
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: org.stripe_customer_id,
      return_url: `${origin}/billing`,
    });

    return NextResponse.json({ url: session.url });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json(
      { message: "Unable to open billing portal." },
      { status: 500 }
    );
  }
}
