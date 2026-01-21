import type { User as SupabaseUser } from "@supabase/supabase-js";
import { createSupabaseAdminClient } from "./admin";
import { createSupabaseServerClient } from "./server";

export class HttpError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export type UserContext = {
  user: SupabaseUser;
  orgId: string;
  role?: string | null;
  profileId: string;
  admin: ReturnType<typeof createSupabaseAdminClient>;
};

export async function requireUserContext(): Promise<UserContext> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getUser();

  if (error || !data.user) {
    throw new HttpError("Unauthorized", 401);
  }

  const admin = createSupabaseAdminClient();

  const { data: profile } = await admin
    .from("profiles")
    .select("id, default_org_id, full_name, email")
    .eq("id", data.user.id)
    .maybeSingle();

  let orgId = profile?.default_org_id ?? null;
  let role: string | null = null;

  if (orgId) {
    const { data: membership } = await admin
      .from("memberships")
      .select("org_id, role")
      .eq("profile_id", data.user.id)
      .eq("org_id", orgId)
      .eq("status", "active")
      .maybeSingle();

    if (membership) {
      role = membership.role ?? null;
    } else {
      orgId = null;
    }
  }

  if (!orgId) {
    const { data: membership } = await admin
      .from("memberships")
      .select("org_id, role")
      .eq("profile_id", data.user.id)
      .eq("status", "active")
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    orgId = membership?.org_id ?? null;
    role = membership?.role ?? null;
  }

  if (!orgId) {
    const { data: bootstrapOrgId, error: bootstrapError } = await supabase.rpc(
      "bootstrap_personal_workspace"
    );

    if (bootstrapError) {
      console.error("bootstrap_personal_workspace failed", bootstrapError);
    } else if (bootstrapOrgId) {
      orgId = bootstrapOrgId;
    }

    if (orgId) {
      const { data: membership } = await admin
        .from("memberships")
        .select("org_id, role")
        .eq("profile_id", data.user.id)
        .eq("org_id", orgId)
        .eq("status", "active")
        .maybeSingle();

      role = membership?.role ?? null;
    }
  }

  if (!orgId) {
    const fullName =
      profile?.full_name ??
      (data.user.user_metadata?.full_name as string | undefined) ??
      (data.user.user_metadata?.name as string | undefined) ??
      data.user.email ??
      "User";
    const email =
      profile?.email ??
      data.user.email ??
      `${data.user.id}@placeholder.local`;

    const profileUpsert = await admin.from("profiles").upsert({
      id: data.user.id,
      email,
      full_name: fullName,
    });

    if (profileUpsert.error) {
      console.error("Profile upsert failed", profileUpsert.error);
    }

    const slugResult = await admin.rpc("generate_org_slug");
    if (slugResult.error) {
      console.error("generate_org_slug failed", slugResult.error);
    }

    const slug =
      typeof slugResult.data === "string"
        ? slugResult.data
        : `${fullName.toLowerCase().replace(/\s+/g, "-")}-${Date.now()}`;

    const orgName = `${fullName}'s Workspace`;
    const orgInsert = await admin
      .from("organizations")
      .insert({ name: orgName, slug })
      .select("id")
      .single();

    if (orgInsert.error || !orgInsert.data?.id) {
      console.error("Organization insert failed", orgInsert.error);
      throw new HttpError("No active organization", 403);
    }

    orgId = orgInsert.data.id;
    role = "owner";

    const membershipInsert = await admin.from("memberships").insert({
      org_id: orgId,
      profile_id: data.user.id,
      role: "owner",
      status: "active",
    });

    if (membershipInsert.error) {
      console.error("Membership insert failed", membershipInsert.error);
      throw new HttpError("No active organization", 403);
    }

    const profileUpdate = await admin
      .from("profiles")
      .update({ default_org_id: orgId })
      .eq("id", data.user.id);

    if (profileUpdate.error) {
      console.error("Profile update failed", profileUpdate.error);
    }

    const creditResult = await admin.rpc("ensure_org_credit_balance", {
      p_org_id: orgId,
      p_plan_code: "free_v1",
    });

    if (creditResult.error) {
      console.error("ensure_org_credit_balance failed", creditResult.error);
    }
  }

  if (!orgId) {
    throw new HttpError("No active organization", 403);
  }

  return {
    user: data.user,
    orgId,
    role,
    profileId: profile?.id ?? data.user.id,
    admin,
  };
}
