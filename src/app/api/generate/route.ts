import { NextResponse } from "next/server";
import { estimateCredits } from "@/lib/credits";
import type { GenerationSettings, Job } from "@/lib/types";
import { HttpError, requireUserContext } from "@/lib/supabase/context";

export async function POST(request: Request) {
  const payload = (await request.json()) as GenerationSettings & {
    title?: string;
  };

  if (!payload.prompt) {
    return NextResponse.json(
      { message: "Prompt is required." },
      { status: 400 }
    );
  }

  try {
    const { admin, orgId, profileId, role } = await requireUserContext();
    if (role && !["owner", "admin"].includes(role)) {
      return NextResponse.json(
        { message: "Insufficient permissions." },
        { status: 403 }
      );
    }
    const now = new Date().toISOString();
    const creditsEstimated = estimateCredits({
      duration: payload.duration,
      quality: payload.quality,
      aspectRatio: payload.aspectRatio,
    });

    const requestInsert = await admin
      .from("ai_requests")
      .insert({
        org_id: orgId,
        profile_id: profileId,
        created_by: profileId,
        request_kind: "generate",
        prompt: payload.prompt,
        model: "sora",
        status: "queued",
        action_code: "video_generate",
        provider: "openai",
        params: payload,
        input_assets: payload.inputImageUrl
          ? [{ url: payload.inputImageUrl }]
          : null,
      })
      .select("id")
      .single();

    const requestId = requestInsert.data?.id ?? null;

    const generationInsert = await admin
      .from("media_generations")
      .insert({
        org_id: orgId,
        created_by: profileId,
        prompt: payload.prompt,
        negative_prompt: payload.negativePrompt ?? null,
        params: {
          ...payload,
          creditsEstimated,
          title: payload.title ?? null,
          requestId,
        },
        provider: "openai",
        model: "sora",
        media_type: "video",
        status: "queued",
      })
      .select("id, created_at, updated_at, status")
      .single();

    if (generationInsert.error || !generationInsert.data) {
      return NextResponse.json(
        { message: "Unable to create generation." },
        { status: 500 }
      );
    }

    const jobInsert = await admin
      .from("render_jobs")
      .insert({
        org_id: orgId,
        generation_id: generationInsert.data.id,
        job_type: "generate",
        status: "queued",
        next_attempt_at: now,
      })
      .select("id, created_at, updated_at, status")
      .single();

    if (jobInsert.error || !jobInsert.data) {
      return NextResponse.json(
        { message: "Unable to create render job." },
        { status: 500 }
      );
    }

    if (requestId) {
      await admin.from("credit_holds").insert({
        org_id: orgId,
        profile_id: profileId,
        request_id: requestId,
        estimated_credits: creditsEstimated,
        status: "held",
      });
    }

    const job: Job = {
      id: jobInsert.data.id,
      title: payload.title || payload.prompt.slice(0, 48),
      status: jobInsert.data.status as Job["status"],
      createdAt: jobInsert.data.created_at,
      updatedAt: jobInsert.data.updated_at,
      progress: 0,
      creditsEstimated,
      settings: payload,
      logs: ["Status: queued"],
    };

    return NextResponse.json({ job });
  } catch (error) {
    if (error instanceof HttpError) {
      return NextResponse.json({ message: error.message }, { status: error.status });
    }
    return NextResponse.json(
      { message: "Unable to create generation." },
      { status: 500 }
    );
  }
}
