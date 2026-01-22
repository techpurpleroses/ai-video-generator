import { NextRequest, NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";
import { mapJobRow } from "@/lib/server/jobs";

type JobRow = {
  id: string;
  status: string;
  created_at: string;
  updated_at: string;
  last_error?: string | null;
  generation?: {
    prompt?: string | null;
    negative_prompt?: string | null;
    params?: Record<string, unknown> | null;
    error_message?: string | null;
  } | null;
  outputs?: {
    file?: {
      bucket?: string | null;
      path?: string | null;
      is_public?: boolean | null;
    } | null;
  }[] | null;
};

export async function POST(
  _request: NextRequest,
  { params: paramsPromise }: { params: Promise<{ id: string }> }
) {
  try {
    const params = await paramsPromise;
    const { admin, orgId, role } = await requireUserContext();
    if (role && !["owner", "admin"].includes(role)) {
      return NextResponse.json(
        { message: "Insufficient permissions." },
        { status: 403 }
      );
    }
    const now = new Date().toISOString();

    const current = await admin
      .from("render_jobs")
      .select("id, attempt_count, generation_id")
      .eq("org_id", orgId)
      .eq("id", params.id)
      .maybeSingle();

    if (current.error || !current.data) {
      return NextResponse.json({ message: "Not found" }, { status: 404 });
    }

    const nextAttempt = (current.data.attempt_count ?? 0) + 1;

    await admin
      .from("render_jobs")
      .update({
        status: "queued",
        attempt_count: nextAttempt,
        next_attempt_at: now,
        last_error: null,
        updated_at: now,
      })
      .eq("org_id", orgId)
      .eq("id", params.id);

    await admin
      .from("media_generations")
      .update({ status: "queued", updated_at: now })
      .eq("id", current.data.generation_id);

    const { data, error } = await admin
      .from("render_jobs")
      .select(
        "id,status,created_at,updated_at,last_error," +
          "generation:media_generations(prompt,negative_prompt,params,error_message)," +
          "outputs:media_outputs(file:files(bucket,path,is_public))"
      )
      .eq("org_id", orgId)
      .eq("id", params.id)
      .maybeSingle();

    if (error || !data) {
      return NextResponse.json({ message: "Not found" }, { status: 404 });
    }

    return NextResponse.json(mapJobRow(data as any));
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to retry job." }, { status: 500 });
  }
}
