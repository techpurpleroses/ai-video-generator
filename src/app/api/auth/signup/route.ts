import { NextResponse } from "next/server";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { buildSessionForUser } from "@/lib/supabase/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function errorResponse(message: string, status = 500) {
  return NextResponse.json({ message }, { status });
}

export async function POST(request: Request) {
  try {
    const payload = (await request.json()) as {
      name?: string;
      email?: string;
      password?: string;
    };

    if (!payload.email || !payload.password || !payload.name) {
      return errorResponse("Name, email, and password are required.", 400);
    }

    const admin = createSupabaseAdminClient();
    const createUserResult = await admin.auth.admin.createUser({
      email: payload.email,
      password: payload.password,
      email_confirm: true,
      user_metadata: {
        full_name: payload.name,
      },
    });

    if (createUserResult.error || !createUserResult.data.user) {
      return errorResponse(
        createUserResult.error?.message ?? "Unable to create user.",
        400
      );
    }

    const user = createUserResult.data.user;

    const profileUpsert = await admin.from("profiles").upsert({
      id: user.id,
      email: payload.email,
      full_name: payload.name,
    });

    if (profileUpsert.error) {
      return errorResponse(profileUpsert.error.message);
    }

    const slugResult = await admin.rpc("generate_org_slug");
    if (slugResult.error) {
      console.error("generate_org_slug failed", slugResult.error);
    }

    const slug =
      typeof slugResult.data === "string"
        ? slugResult.data
        : `${payload.name.toLowerCase().replace(/\s+/g, "-")}-${Date.now()}`;

    const orgName = `${payload.name}'s Workspace`;
    const orgInsert = await admin
      .from("organizations")
      .insert({ name: orgName, slug })
      .select("id")
      .single();

    if (orgInsert.error || !orgInsert.data?.id) {
      return errorResponse(
        orgInsert.error?.message ?? "Unable to create organization."
      );
    }

    const membershipInsert = await admin.from("memberships").insert({
      org_id: orgInsert.data.id,
      profile_id: user.id,
      role: "owner",
      status: "active",
    });

    if (membershipInsert.error) {
      return errorResponse(membershipInsert.error.message);
    }

    const profileUpdate = await admin
      .from("profiles")
      .update({ default_org_id: orgInsert.data.id })
      .eq("id", user.id);

    if (profileUpdate.error) {
      return errorResponse(profileUpdate.error.message);
    }

    const creditResult = await admin.rpc("ensure_org_credit_balance", {
      p_org_id: orgInsert.data.id,
      p_plan_code: "free_v1",
    });

    if (creditResult.error) {
      return errorResponse(creditResult.error.message);
    }

    const supabase = await createSupabaseServerClient();
    const signInResult = await supabase.auth.signInWithPassword({
      email: payload.email,
      password: payload.password,
    });

    if (signInResult.error || !signInResult.data.user) {
      return errorResponse(
        signInResult.error?.message ?? "Account created, but sign-in failed."
      );
    }

    const session = await buildSessionForUser(signInResult.data.user);
    return NextResponse.json({ session });
  } catch (error) {
    console.error("Signup failed", error);
    return errorResponse("Unable to create account.");
  }
}
