import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";

export async function GET() {
  try {
    const { admin, orgId, role } = await requireUserContext();

    if (role && !["owner", "admin"].includes(role)) {
      return NextResponse.json(
        { message: "Insufficient permissions." },
        { status: 403 }
      );
    }

    const usersCount = await admin
      .from("memberships")
      .select("profile_id", { count: "exact", head: true })
      .eq("org_id", orgId);

    const jobsCount = await admin
      .from("render_jobs")
      .select("id", { count: "exact", head: true })
      .eq("org_id", orgId);

    const failuresCount = await admin
      .from("render_jobs")
      .select("id", { count: "exact", head: true })
      .eq("org_id", orgId)
      .eq("status", "failed");

    const { data: usage } = await admin
      .from("usage_events")
      .select("units, unit_type")
      .eq("org_id", orgId);

    const usageSeconds =
      usage?.reduce((sum, row) => {
        if (row.unit_type === "seconds") {
          return sum + Number(row.units ?? 0);
        }
        return sum;
      }, 0) ?? 0;

    return NextResponse.json({
      users: usersCount.count ?? 0,
      jobs: jobsCount.count ?? 0,
      usageSeconds,
      failures: failuresCount.count ?? 0,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to load summary." }, { status: 500 });
  }
}
