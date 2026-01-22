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

function isJobRow(x: unknown): x is JobRow {
  if (!x || typeof x !== "object") return false;
  const o = x as Record<string, unknown>;
  return (
    typeof o.id === "string" &&
    typeof o.status === "string" &&
    typeof o.created_at === "string" &&
    typeof o.updated_at === "string"
  );
}

export async function GET(
  _request: NextRequest,
  { params: paramsPromise }: { params: Promise<{ id: string }> }
) {
  try {
    const params = await paramsPromise;
    const { admin, orgId } = await requireUserContext();

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

    if (error || !data || !isJobRow(data)) {
      return NextResponse.json({ message: "Not found" }, { status: 404 });
    }

    return NextResponse.json(mapJobRow(data));
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to load job." }, { status: 500 });
  }
}
