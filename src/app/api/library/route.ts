import { NextResponse } from "next/server";
import { HttpError, requireUserContext } from "@/lib/supabase/context";
import { mapMediaRow } from "@/lib/server/library";

const PAGE_SIZE = 6;

type MediaRow = Parameters<typeof mapMediaRow>[0];

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const status = searchParams.get("status");
  const type = searchParams.get("type");
  const from = searchParams.get("from");
  const to = searchParams.get("to");
  const cursor = Number(searchParams.get("cursor") ?? 0) || 0;

  try {
    const { admin, orgId } = await requireUserContext();

    let query = admin
      .from("media_generations")
      .select(
        "id,status,prompt,negative_prompt,params,created_at," +
          "outputs:media_outputs(file:files(bucket,path,is_public))"
      )
      .eq("org_id", orgId)
      .order("created_at", { ascending: false });

    if (from) query = query.gte("created_at", from);
    if (to) query = query.lte("created_at", to);

    if (type && type !== "all") {
      const mode = type === "image-to-video" ? "image" : "text";
      query = query.eq("params->>mode", mode);
    }

    const { data, error } = await query
      .range(cursor, cursor + PAGE_SIZE - 1)
      .returns<MediaRow[]>();

    if (error) {
      return NextResponse.json(
        { message: "Unable to load library." },
        { status: 500 }
      );
    }

    let items = (data ?? []).map(mapMediaRow);

    if (status && status !== "all") {
      items = items.filter((item) => item.status === status);
    }

    const nextCursor =
      data && data.length === PAGE_SIZE ? String(cursor + PAGE_SIZE) : null;

    return NextResponse.json({ items, nextCursor });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json(
        { message: error.message },
        { status: error.status }
      );
    }
    return NextResponse.json({ message: "Unable to load library." }, { status: 500 });
  }
}
