import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";
import { mapJobRow } from "@/lib/server/jobs";

export async function POST(
  _request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const { admin, orgId, role } = await requireUserContext();
    if (role && !["owner", "admin"].includes(role)) {
      return NextResponse.json(
        { message: "Insufficient permissions." },
        { status: 403 }
      );
    }
    const now = new Date().toISOString();

    const updated = await admin
      .from("render_jobs")
      .update({ status: "canceled", updated_at: now })
      .eq("org_id", orgId)
      .eq("id", params.id)
      .select("id, generation_id")
      .maybeSingle();

    if (updated.error || !updated.data) {
      return NextResponse.json({ message: "Not found" }, { status: 404 });
    }

    await admin
      .from("media_generations")
      .update({ status: "canceled", updated_at: now })
      .eq("id", updated.data.generation_id);

    const { data } = await admin
      .from("render_jobs")
      .select(
        "id,status,created_at,updated_at,last_error," +
          "generation:media_generations(prompt,negative_prompt,params,error_message)," +
          "outputs:media_outputs(file:files(bucket,path,is_public))"
      )
      .eq("org_id", orgId)
      .eq("id", params.id)
      .maybeSingle();

    if (!data) {
      return NextResponse.json({ message: "Not found" }, { status: 404 });
    }

    return NextResponse.json(mapJobRow(data));
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json({ message: "Unable to cancel job." }, { status: 500 });
  }
}
