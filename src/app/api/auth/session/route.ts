import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { buildSessionForUser } from "@/lib/supabase/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.auth.getUser();

    if (error || !data.user) {
      return NextResponse.json({ message: "Unauthorized" }, { status: 401 });
    }

    const session = await buildSessionForUser(data.user);
    return NextResponse.json({ session });
  } catch (error) {
    console.error("Session fetch failed", error);
    return NextResponse.json(
      { message: "Unable to fetch session." },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    let payload: { email?: string; password?: string };
    try {
      payload = (await request.json()) as { email?: string; password?: string };
    } catch {
      return NextResponse.json(
        { message: "Invalid request payload." },
        { status: 400 }
      );
    }

    if (!payload.email || !payload.password) {
      return NextResponse.json(
        { message: "Email and password are required." },
        { status: 400 }
      );
    }

    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase.auth.signInWithPassword({
      email: payload.email,
      password: payload.password,
    });

    if (error || !data.user) {
      return NextResponse.json(
        { message: "Invalid credentials." },
        { status: 401 }
      );
    }

    const session = await buildSessionForUser(data.user);
    return NextResponse.json({ session });
  } catch (error) {
    console.error("Login failed", error);
    return NextResponse.json(
      { message: "Unable to sign in." },
      { status: 500 }
    );
  }
}