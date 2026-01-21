import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    let payload: { email?: string };
    try {
      payload = (await request.json()) as { email?: string };
    } catch {
      return NextResponse.json(
        { message: "Invalid request payload." },
        { status: 400 }
      );
    }

    if (!payload.email) {
      return NextResponse.json(
        { message: "Email is required." },
        { status: 400 }
      );
    }

    const supabase = await createSupabaseServerClient();
    const origin =
      request.headers.get("origin") ?? process.env.NEXT_PUBLIC_SITE_URL ?? "";
    const redirectTo = origin ? new URL("/reset-password", origin).toString() : undefined;

    const { error } = await supabase.auth.resetPasswordForEmail(payload.email, {
      redirectTo,
    });

    if (error) {
      return NextResponse.json({ message: error.message }, { status: 400 });
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Forgot password request failed", error);
    return NextResponse.json(
      { message: "Unable to send reset link." },
      { status: 500 }
    );
  }
}
