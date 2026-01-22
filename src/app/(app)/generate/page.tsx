"use client";

import { useState } from "react";
import { toast } from "sonner";
import { PageHeader } from "@/components/common/page-header";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { productConfig } from "@/lib/config/product";
import {
  PromptBuilder,
  type PromptValues,
} from "@/features/video/components/prompt-builder";
import { CostEstimator } from "@/features/video/components/cost-estimator";
import { JobQueuePanel } from "@/features/video/components/job-queue-panel";
import { useCreateGeneration } from "@/features/video/hooks";
import type { GeneratePayload } from "@/features/video/types";

const defaultSettings: PromptValues = {
  prompt: "",
  negativePrompt: "",
  stylePreset: productConfig.stylePresets[0],
  aspectRatio: productConfig.aspectRatios[0],
  duration: productConfig.durations[0],
  quality: productConfig.qualities[1],
  cameraMovement: productConfig.cameraMoves[0],
  seed: "",
};

export default function GeneratePage() {
  const [activeMode, setActiveMode] = useState<string>(
    productConfig.generatorModes[0].key
  );
  const [settings, setSettings] = useState(defaultSettings);
  const { mutateAsync, isPending } = useCreateGeneration();

  async function handleGenerate(payload: GeneratePayload) {
    try {
      await mutateAsync(payload);
      toast.success("Generation queued.");
    } catch (error) {
      toast.error("Failed to queue generation.");
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Generation studio"
        description="Compose prompts, estimate cost, and queue new jobs."
      />

      <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
        <div className="rounded-2xl border border-border/60 bg-card p-6">
          <Tabs value={activeMode} onValueChange={setActiveMode}>
            <TabsList className="flex flex-wrap gap-2">
              {productConfig.generatorModes.map((mode) => (
                <TabsTrigger
                  key={mode.key}
                  value={mode.key}
                  disabled={!mode.enabled}
                >
                  {mode.label}
                  {!mode.enabled && productConfig.features.showComingSoon ? (
                    <span className="ml-2 text-[10px] uppercase text-muted-foreground">
                      Soon
                    </span>
                  ) : null}
                </TabsTrigger>
              ))}
            </TabsList>

            <TabsContent value={activeMode}>
              <div className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
                <PromptBuilder
                  mode={activeMode}
                  onSubmit={(payload) => handleGenerate(payload)}
                  isSubmitting={isPending}
                  onSettingsChange={(next) => setSettings(next)}
                />
                <CostEstimator
                  duration={settings.duration}
                  quality={settings.quality}
                  aspectRatio={settings.aspectRatio}
                />
              </div>
            </TabsContent>
          </Tabs>
        </div>

        <JobQueuePanel />
      </div>
    </div>
  );
}
