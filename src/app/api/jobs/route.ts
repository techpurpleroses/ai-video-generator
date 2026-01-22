import { NextResponse } from "next/server";
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

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const status = searchParams.get("status");

  try {
    const { admin, orgId } = await requireUserContext();

    let query = admin
      .from("render_jobs")
      .select(
        "id,status,created_at,updated_at,last_error," +
          "generation:media_generations(prompt,negative_prompt,params,error_message)," +
          "outputs:media_outputs(file:files(bucket,path,is_public))"
      )
      .eq("org_id", orgId);

    if (status && status !== "all") {
      query = query.eq("status", status);
    }

    const { data, error } = await query.order("created_at", { ascending: false });

    if (error) {
      return NextResponse.json({ message: "Unable to load jobs." }, { status: 500 });
    }

    // Supabase client typings can sometimes surface as GenericStringError[].
    // Convert to unknown[] first, then safely narrow with a type-guard.
    const rawRows = (data ?? []) as unknown[];
    const rows = rawRows.filter(isJobRow);
    const jobs = rows.map(mapJobRow);

    return NextResponse.json(jobs);
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to load jobs." }, { status: 500 });
  }
}
