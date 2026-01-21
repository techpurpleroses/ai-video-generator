import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { createClient } from "@supabase/supabase-js";

const PROJECT_ROOT = process.cwd();

const ENV_FILES = [".env.local", ".env"];

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }
  const contents = fs.readFileSync(filePath, "utf8");
  contents.split(/\r?\n/).forEach((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      return;
    }
    const cleaned = trimmed.startsWith("export ")
      ? trimmed.slice("export ".length)
      : trimmed;
    const index = cleaned.indexOf("=");
    if (index === -1) {
      return;
    }
    const key = cleaned.slice(0, index).trim();
    const rawValue = cleaned.slice(index + 1).trim();
    const value = rawValue.replace(/^"(.*)"$/, "$1");
    if (!process.env[key]) {
      process.env[key] = value;
    }
  });
}

ENV_FILES.forEach((file) => loadEnvFile(path.join(PROJECT_ROOT, file)));

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ||
  process.env.SUPABASE_URL ||
  (process.env.SUPABASE_PROJECT_REF
    ? `https://${process.env.SUPABASE_PROJECT_REF}.supabase.co`
    : "");
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";

const OPENAI_SORA_ENDPOINT =
  process.env.OPENAI_SORA_ENDPOINT || "https://api.openai.com/v1/video/generations";
const OPENAI_SORA_STATUS_ENDPOINT = process.env.OPENAI_SORA_STATUS_ENDPOINT || "";
const OPENAI_SORA_MODEL = process.env.OPENAI_SORA_MODEL || "sora";
const OPENAI_SORA_MODE =
  process.env.OPENAI_SORA_MODE ||
  (OPENAI_SORA_ENDPOINT.includes("/responses") ? "responses" : "video");
const SORA_OUTPUT_BUCKET = process.env.SORA_OUTPUT_BUCKET || "media";

const WORKER_POLL_INTERVAL_MS = Number(
  process.env.WORKER_POLL_INTERVAL_MS || 5000
);
const WORKER_LOCK_TIMEOUT_MS = Number(
  process.env.WORKER_LOCK_TIMEOUT_MS || 10 * 60 * 1000
);
const WORKER_ID = process.env.WORKER_ID || `${os.hostname()}-${process.pid}`;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing Supabase credentials.");
  process.exit(1);
}

if (!OPENAI_API_KEY) {
  console.error("Missing OPENAI_API_KEY.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

console.log("Using Supabase URL:", SUPABASE_URL);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}


function cleanObject(payload) {
  return Object.fromEntries(
    Object.entries(payload).filter(([, value]) => value !== undefined)
  );
}

function parseDurationSeconds(duration) {
  if (typeof duration === "number") {
    return duration;
  }
  if (typeof duration !== "string") {
    return undefined;
  }
  const trimmed = duration.trim().toLowerCase();
  if (trimmed.endsWith("s")) {
    const parsed = Number(trimmed.slice(0, -1));
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function extractVideoOutput(payload) {
  if (!payload || typeof payload !== "object") {
    return {};
  }

  const directUrl =
    payload.output_url ||
    payload.video_url ||
    payload.url ||
    payload.result_url ||
    payload.resultUrl;
  if (typeof directUrl === "string") {
    return { url: directUrl };
  }

  if (Array.isArray(payload.data)) {
    const item = payload.data[0];
    if (item?.url) {
      return { url: item.url };
    }
    if (item?.b64_json) {
      return { base64: item.b64_json, mimeType: "video/mp4" };
    }
  }

  if (Array.isArray(payload.output)) {
    for (const entry of payload.output) {
      if (entry?.url) {
        return { url: entry.url };
      }
      if (entry?.content && Array.isArray(entry.content)) {
        for (const content of entry.content) {
          if (content?.url) {
            return { url: content.url };
          }
          if (content?.b64_json) {
            return { base64: content.b64_json, mimeType: "video/mp4" };
          }
        }
      }
    }
  }

  return {};
}

function extractStatusUrl(payload) {
  if (!payload || typeof payload !== "object") {
    return undefined;
  }
  const candidates = [
    payload.status_url,
    payload.statusUrl,
    payload.retrieve_url,
    payload.retrieveUrl,
    payload.result_url,
    payload.resultUrl,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === "string") {
      return candidate;
    }
  }
  if (payload.id && OPENAI_SORA_STATUS_ENDPOINT) {
    return `${OPENAI_SORA_STATUS_ENDPOINT.replace(/\/$/, "")}/${payload.id}`;
  }
  return undefined;
}

async function ensureBucket(name) {
  const { data, error } = await supabase.storage.listBuckets();
  if (error) {
    throw error;
  }
  const existing = data?.find((bucket) => bucket.name === name);
  if (!existing) {
    const created = await supabase.storage.createBucket(name, { public: true });
    if (created.error) {
      throw created.error;
    }
  } else if (!existing.public) {
    await supabase.storage.updateBucket(name, { public: true });
  }
}

async function fetchNextJob() {

  console.log("Fetching next job...");

  const now = new Date();

  const nowIso = now.toISOString();

  const staleIso = new Date(now.getTime() - WORKER_LOCK_TIMEOUT_MS).toISOString();



  const query = supabase

    .from("render_jobs")

    .select(

      "id, org_id, status, attempt_count, max_attempts, next_attempt_at, locked_at, locked_by, provider_job_id,"

        +

        "generation:media_generations(id, org_id, created_by, prompt, negative_prompt, params, status, provider, model)"

    )

    .eq("status", "queued")

    .lte("next_attempt_at", nowIso)

    .or(`locked_at.is.null,locked_at.lt.${staleIso}`)

    .order("created_at", { ascending: true })

    .limit(1);



  const { data, error } = await query.maybeSingle();

  if (error) {

    console.error("Unable to fetch job:", error.message);

    return null;

  }

  console.log("Fetched job:", data);

  return data ?? null;

}

async function claimJob(job) {
  const nowIso = new Date().toISOString();
  let update = supabase
    .from("render_jobs")
    .update({
      status: "running",
      locked_at: nowIso,
      locked_by: WORKER_ID,
      attempt_count: (job.attempt_count ?? 0) + 1,
      updated_at: nowIso,
    })
    .eq("id", job.id)
    .eq("status", job.status ?? "queued");

  if (job.locked_at) {
    update = update.eq("locked_at", job.locked_at);
  } else {
    update = update.is("locked_at", null);
  }

  const { data, error } = await update.select("id").maybeSingle();
  if (error || !data) {
    return false;
  }

  if (job.generation?.id) {
    await supabase
      .from("media_generations")
      .update({ status: "running", updated_at: nowIso })
      .eq("id", job.generation.id);
  }

  return true;
}

function buildSoraPayload(generation) {
  const params = generation.params ?? {};
  const durationSeconds = parseDurationSeconds(params.duration);
  const base = {
    model: OPENAI_SORA_MODEL,
    prompt: generation.prompt,
    negative_prompt: generation.negative_prompt ?? undefined,
    duration: durationSeconds ?? undefined,
    aspect_ratio: params.aspectRatio ?? params.aspect_ratio,
    quality: params.quality,
    seed: params.seed,
    image_url: params.inputImageUrl ?? params.input_image_url,
  };

  if (OPENAI_SORA_MODE === "responses") {
    return {
      model: OPENAI_SORA_MODEL,
      input: [
        {
          role: "user",
          content: [
            { type: "input_text", text: generation.prompt || "" },
          ],
        },
      ],
    };
  }

  return cleanObject(base);
}

async function requestSoraVideo(generation) {
  const body = buildSoraPayload(generation);
  const startedAt = Date.now();
  const response = await fetch(OPENAI_SORA_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const contentType = response.headers.get("content-type") || "";
  if (contentType.startsWith("video/") || contentType === "application/octet-stream") {
    if (!response.ok) {
      throw new Error(`OpenAI error ${response.status}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return {
      output: {
        base64: Buffer.from(arrayBuffer).toString("base64"),
        mimeType: contentType || "video/mp4",
      },
      statusUrl: undefined,
      payload: { status: "succeeded" },
      responseMs: Date.now() - startedAt,
    };
  }
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      `OpenAI error ${response.status}`;
    throw new Error(message);
  }
  const output = extractVideoOutput(payload);
  const statusUrl = extractStatusUrl(payload);
  return {
    output,
    statusUrl,
    payload,
    responseMs: Date.now() - startedAt,
  };
}

async function pollForResult(statusUrl, timeoutMs = 10 * 60 * 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const response = await fetch(statusUrl, {
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
    });
    const payload = await response.json().catch(() => ({}));
    if (response.ok) {
      const output = extractVideoOutput(payload);
      if (output.url || output.base64) {
        return { payload, output };
      }
      if (payload.status && payload.status !== "running") {
        throw new Error(`Provider status: ${payload.status}`);
      }
    }
    await sleep(5000);
  }
  throw new Error("Timed out waiting for provider response.");
}

async function downloadOutput(output) {
  if (output.base64) {
    const buffer = Buffer.from(output.base64, "base64");
    return {
      buffer,
      contentType: output.mimeType || "video/mp4",
    };
  }

  if (!output.url) {
    throw new Error("No output URL returned.");
  }

  const response = await fetch(output.url);
  if (!response.ok) {
    throw new Error(`Unable to download output: ${response.status}`);
  }
  const contentType = response.headers.get("content-type") || "video/mp4";
  const arrayBuffer = await response.arrayBuffer();
  return {
    buffer: Buffer.from(arrayBuffer),
    contentType,
  };
}

function pickBucket(balance, credits) {
  if (balance.free_credits_available >= credits) {
    return { bucket: "free", free: credits };
  }
  if (balance.paid_credits_available >= credits) {
    return { bucket: "paid", paid: credits };
  }
  if (balance.bonus_credits_available >= credits) {
    return { bucket: "bonus", bonus: credits };
  }
  return { bucket: "free", free: credits };
}

async function finalizeCredits({
  orgId,
  requestId,
  generationId,
  jobId,
  estimatedCredits,
  durationSeconds,
}) {
  if (!requestId || !estimatedCredits) {
    return;
  }
  const { data: hold } = await supabase
    .from("credit_holds")
    .select("id, status, estimated_credits, profile_id")
    .eq("request_id", requestId)
    .maybeSingle();

  if (!hold || hold.status !== "held") {
    return;
  }

  const credits = hold.estimated_credits ?? estimatedCredits;
  if (!credits || credits <= 0) {
    return;
  }

  const { data: balance } = await supabase
    .from("org_credit_balances")
    .select("free_credits_available, paid_credits_available, bonus_credits_available")
    .eq("org_id", orgId)
    .maybeSingle();

  if (!balance) {
    return;
  }

  const available =
    balance.free_credits_available +
    balance.paid_credits_available +
    balance.bonus_credits_available;

  if (available < credits) {
    throw new Error("Insufficient credits.");
  }

  const allocation = pickBucket(balance, credits);
  const updatedBalance = {
    free_credits_available:
      balance.free_credits_available - (allocation.free ?? 0),
    paid_credits_available:
      balance.paid_credits_available - (allocation.paid ?? 0),
    bonus_credits_available:
      balance.bonus_credits_available - (allocation.bonus ?? 0),
    updated_at: new Date().toISOString(),
  };

  await supabase
    .from("org_credit_balances")
    .update(updatedBalance)
    .eq("org_id", orgId);

  await supabase.from("credit_transactions").insert({
    org_id: orgId,
    profile_id: hold.profile_id ?? null,
    request_id: requestId,
    bucket: allocation.bucket,
    change: -credits,
    reason: "video_generation",
  });

  await supabase
    .from("usage_events")
    .insert({
      org_id: orgId,
      profile_id: hold.profile_id ?? null,
      request_id: requestId,
      event_type: "video_generate",
      action_code: "video_generate",
      unit_type: "seconds",
      units: durationSeconds ?? 0,
      credits_charged: credits,
      generation_id: generationId ?? null,
      job_id: jobId ?? null,
      metadata: { provider: "openai", model: OPENAI_SORA_MODEL },
    });

  await supabase
    .from("credit_holds")
    .update({ status: "finalized", finalized_at: new Date().toISOString() })
    .eq("id", hold.id);
}

async function releaseCredits(requestId) {
  if (!requestId) {
    return;
  }
  await supabase
    .from("credit_holds")
    .update({ status: "released", finalized_at: new Date().toISOString() })
    .eq("request_id", requestId)
    .eq("status", "held");
}

async function uploadOutput({
  buffer,
  contentType,
  orgId,
  generationId,
  jobId,
  requestId,
  profileId,
}) {
  const ext = contentType.includes("mp4") ? "mp4" : "bin";
  const fileName = `sora-${generationId}-${Date.now()}.${ext}`;
  const objectPath = `${orgId}/${generationId}/${fileName}`;

  const upload = await supabase.storage
    .from(SORA_OUTPUT_BUCKET)
    .upload(objectPath, buffer, {
      contentType,
      upsert: true,
    });

  if (upload.error) {
    throw upload.error;
  }

  const fileUpsert = await supabase
    .from("files")
    .upsert(
      {
        org_id: orgId,
        profile_id: profileId ?? null,
        bucket: SORA_OUTPUT_BUCKET,
        path: objectPath,
        file_name: fileName,
        mime_type: contentType,
        size_bytes: buffer.length,
        provider: "supabase",
        source: "ai_generated",
        request_id: requestId ?? null,
        metadata: { provider: "openai", model: OPENAI_SORA_MODEL },
        is_public: true,
      },
      { onConflict: "bucket,path" }
    )
    .select("id")
    .maybeSingle();

  if (fileUpsert.error || !fileUpsert.data) {
    throw fileUpsert.error || new Error("Unable to upsert file record.");
  }

  await supabase.from("media_outputs").insert({
    org_id: orgId,
    generation_id: generationId,
    job_id: jobId,
    file_id: fileUpsert.data.id,
    output_type: "video",
    metadata: { provider: "openai", model: OPENAI_SORA_MODEL },
  });

  return {
    fileId: fileUpsert.data.id,
    bucket: SORA_OUTPUT_BUCKET,
    path: objectPath,
  };
}

async function processJob(job) {
  if (!job?.generation) {
    return;
  }

  const claimed = await claimJob(job);
  if (!claimed) {
    return;
  }

  const generation = job.generation;
  const params = generation.params ?? {};
  const requestId = params.requestId || params.request_id || null;
  const durationSeconds = parseDurationSeconds(params.duration);
  const estimatedCredits =
    typeof params.creditsEstimated === "number"
      ? params.creditsEstimated
      : undefined;

  try {
    const response = await requestSoraVideo(generation);
    let output = response.output;
    if (!output.url && !output.base64) {
      if (!response.statusUrl) {
        throw new Error("Provider did not return output.");
      }
      const polled = await pollForResult(response.statusUrl);
      output = polled.output;
    }

    const downloaded = await downloadOutput(output);
    await uploadOutput({
      buffer: downloaded.buffer,
      contentType: downloaded.contentType,
      orgId: job.org_id,
      generationId: generation.id,
      jobId: job.id,
      requestId,
      profileId: generation.created_by,
    });

    await supabase
      .from("render_jobs")
      .update({
        status: "succeeded",
        last_error: null,
        locked_at: null,
        locked_by: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", job.id);

    await supabase
      .from("media_generations")
      .update({
        status: "succeeded",
        error_message: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", generation.id);

    if (requestId) {
      await supabase
        .from("ai_requests")
        .update({
          status: "succeeded",
          completed_at: new Date().toISOString(),
        })
        .eq("id", requestId);
    }

    await finalizeCredits({
      orgId: job.org_id,
      requestId,
      generationId: generation.id,
      jobId: job.id,
      estimatedCredits,
      durationSeconds,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Generation failed.";
    await supabase
      .from("render_jobs")
      .update({
        status: "failed",
        last_error: message,
        locked_at: null,
        locked_by: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", job.id);

    await supabase
      .from("media_generations")
      .update({
        status: "failed",
        error_message: message,
        updated_at: new Date().toISOString(),
      })
      .eq("id", generation.id);

    if (requestId) {
      await supabase
        .from("ai_requests")
        .update({
          status: "failed",
          error_message: message,
          completed_at: new Date().toISOString(),
        })
        .eq("id", requestId);
      await releaseCredits(requestId);
    }
  }
}

async function main() {
  const runOnce = process.argv.includes("--once");
  await ensureBucket(SORA_OUTPUT_BUCKET);
  console.log(`Worker ${WORKER_ID} listening for jobs...`);

  do {
    const job = await fetchNextJob();
    if (job) {
      await processJob(job);
      if (runOnce) {
        break;
      }
      continue;
    }
    if (runOnce) {
      break;
    }
    await sleep(WORKER_POLL_INTERVAL_MS);
  } while (true);
}

main().catch((error) => {
  console.error("Worker crashed:", error);
  process.exit(1);
});
