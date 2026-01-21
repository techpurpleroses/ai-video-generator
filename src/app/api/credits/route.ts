import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";

export async function GET() {
  try {
    const { admin, orgId } = await requireUserContext();

    let balance = await admin
      .from("org_credit_balances")
      .select(
        "free_credits_available, paid_credits_available, bonus_credits_available"
      )
      .eq("org_id", orgId)
      .maybeSingle();

    if (!balance.data) {
      await admin.rpc("ensure_org_credit_balance", {
        p_org_id: orgId,
        p_plan_code: "free_v1",
      });
      balance = await admin
        .from("org_credit_balances")
        .select(
          "free_credits_available, paid_credits_available, bonus_credits_available"
        )
        .eq("org_id", orgId)
        .maybeSingle();
    }

    const available =
      (balance.data?.free_credits_available ?? 0) +
      (balance.data?.paid_credits_available ?? 0) +
      (balance.data?.bonus_credits_available ?? 0);

    const { data: holds } = await admin
      .from("credit_holds")
      .select("estimated_credits")
      .eq("org_id", orgId)
      .eq("status", "held");

    const reserved =
      holds?.reduce((sum, row) => sum + (row.estimated_credits ?? 0), 0) ?? 0;

    const { data: transactions } = await admin
      .from("credit_transactions")
      .select("id, created_at, reason, change, request_id")
      .eq("org_id", orgId)
      .order("created_at", { ascending: false })
      .limit(50);

    const requestIds = (transactions ?? [])
      .map((txn) => txn.request_id)
      .filter((id): id is string => typeof id === "string");

    let requestMap = new Map<string, string>();
    if (requestIds.length > 0) {
      const { data: usage } = await admin
        .from("usage_events")
        .select("request_id, job_id")
        .in("request_id", requestIds);

      (usage ?? []).forEach((row) => {
        if (row.request_id && row.job_id) {
          requestMap.set(row.request_id, row.job_id);
        }
      });
    }

    const ledger =
      transactions?.map((txn) => ({
        id: String(txn.id),
        createdAt: txn.created_at,
        description: txn.reason.replace(/_/g, " "),
        delta: txn.change,
        jobId: txn.request_id ? requestMap.get(txn.request_id) : undefined,
      })) ?? [];

    return NextResponse.json({
      available,
      reserved,
      holds: reserved,
      ledger,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to load credits." }, { status: 500 });
  }
}
