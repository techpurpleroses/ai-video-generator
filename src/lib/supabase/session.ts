import type { User as SupabaseUser } from "@supabase/supabase-js";
import type { Session } from "@/lib/types";
import { createSupabaseAdminClient } from "./admin";

function normalizePlanName(value?: string | null): Session["plan"] {
  const normalized = (value ?? "").toLowerCase();
  if (normalized.includes("pro")) {
    return "Pro";
  }
  if (normalized.includes("business") || normalized.includes("enterprise")) {
    return "Business";
  }
  return "Free";
}

export async function buildSessionForUser(user: SupabaseUser): Promise<Session> {
  const admin = createSupabaseAdminClient();

  let { data: profile } = await admin
    .from("profiles")
    .select("id, full_name, email, avatar_url, default_org_id")
    .eq("id", user.id)
    .maybeSingle();

  const fullName =
    profile?.full_name ??
    (user.user_metadata?.full_name as string | undefined) ??
    (user.user_metadata?.name as string | undefined) ??
    user.email ??
    "User";

  const email = profile?.email ?? user.email ?? "";

  if (!profile) {
    await admin.from("profiles").insert({
      id: user.id,
      email: user.email,
      full_name: fullName,
    });
    profile = {
      id: user.id,
      full_name: fullName,
      email,
      avatar_url: null,
      default_org_id: null,
    };
  }

  let orgId = profile.default_org_id ?? null;

  if (!orgId) {
    const { data: membership } = await admin
      .from("memberships")
      .select("org_id")
      .eq("profile_id", user.id)
      .eq("status", "active")
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    orgId = membership?.org_id ?? null;
  }

  let plan: Session["plan"] = "Free";

  if (orgId) {
    const { data: subscription } = await admin
      .from("subscriptions")
      .select("plan_code")
      .eq("org_id", orgId)
      .in("status", ["active", "trialing"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (subscription?.plan_code) {
      const { data: planRow } = await admin
        .from("plan_catalog")
        .select("name, plan_code")
        .eq("plan_code", subscription.plan_code)
        .maybeSingle();

      plan = normalizePlanName(planRow?.name ?? subscription.plan_code);
    }
  }

  return {
    user: {
      id: user.id,
      name: fullName,
      email,
      avatarUrl:
        profile?.avatar_url ??
        (user.user_metadata?.avatar_url as string | undefined) ??
        undefined,
    },
    plan,
  };
}
