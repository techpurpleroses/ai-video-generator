"use client";

import { useEffect, useMemo, useState } from "react";
import { productConfig } from "@/lib/config/product";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { generationSchema } from "@/features/video/schema";
import type { GeneratePayload } from "@/features/video/types";
import { useGeneratorStore } from "@/features/video/store";

type PromptBuilderProps = {
  mode: string;
  onSubmit: (payload: GeneratePayload) => void;
  isSubmitting?: boolean;
  onSettingsChange?: (values: typeof initialState) => void;
};

const initialState = {
  prompt: "",
  negativePrompt: "",
  stylePreset: productConfig.stylePresets[0],
  aspectRatio: productConfig.aspectRatios[0],
  duration: productConfig.durations[0],
  quality: productConfig.qualities[1],
  cameraMovement: productConfig.cameraMoves[0],
  seed: "",
};

export function PromptBuilder({
  mode,
  onSubmit,
  isSubmitting,
  onSettingsChange,
}: PromptBuilderProps) {
  const { draft, clearDraft } = useGeneratorStore();
  const [values, setValues] = useState(initialState);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  useEffect(() => {
    if (draft) {
      setValues({
        prompt: draft.prompt,
        negativePrompt: draft.negativePrompt ?? "",
        stylePreset: draft.stylePreset,
        aspectRatio: draft.aspectRatio,
        duration: draft.duration,
        quality: draft.quality,
        cameraMovement: draft.cameraMovement,
        seed: draft.seed ?? "",
      });
      setImagePreview(draft.inputImageUrl ?? null);
      clearDraft();
    }
  }, [draft, clearDraft]);

  useEffect(() => {
    onSettingsChange?.(values);
  }, [onSettingsChange, values]);

  const payload = useMemo<GeneratePayload>(
    () => ({
      mode,
      prompt: values.prompt,
      negativePrompt: values.negativePrompt || undefined,
      stylePreset: values.stylePreset,
      aspectRatio: values.aspectRatio,
      duration: values.duration,
      quality: values.quality,
      cameraMovement: values.cameraMovement,
      seed: values.seed || undefined,
      inputImageUrl: mode === "image" ? imagePreview ?? undefined : undefined,
    }),
    [imagePreview, mode, values]
  );

  function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    const result = generationSchema.safeParse(values);
    if (!result.success) {
      const fieldErrors: Record<string, string> = {};
      result.error.errors.forEach((err) => {
        const key = err.path[0];
        if (key && !fieldErrors[String(key)]) {
          fieldErrors[String(key)] = err.message;
        }
      });
      setErrors(fieldErrors);
      return;
    }
    setErrors({});
    onSubmit(payload);
  }

  function handleImageChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) {
      setImagePreview(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setImagePreview(url);
  }

  return (
    <form className="space-y-5" onSubmit={handleSubmit}>
      <div className="space-y-2">
        <Label htmlFor="prompt">Prompt</Label>
        <Textarea
          id="prompt"
          value={values.prompt}
          onChange={(event) =>
            setValues((prev) => ({ ...prev, prompt: event.target.value }))
          }
          placeholder="Describe the scene, lighting, camera, and style."
        />
        {errors.prompt ? (
          <p className="text-xs text-destructive">{errors.prompt}</p>
        ) : null}
      </div>

      <div className="space-y-2">
        <Label htmlFor="negativePrompt">Negative prompt (optional)</Label>
        <Input
          id="negativePrompt"
          value={values.negativePrompt}
          onChange={(event) =>
            setValues((prev) => ({
              ...prev,
              negativePrompt: event.target.value,
            }))
          }
          placeholder="Avoid motion blur, low detail, oversaturation."
        />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <Label>Style preset</Label>
          <Select
            value={values.stylePreset}
            onValueChange={(value) =>
              setValues((prev) => ({ ...prev, stylePreset: value }))
            }
          >
            <SelectTrigger>
              <SelectValue placeholder="Select a style" />
            </SelectTrigger>
            <SelectContent>
              {productConfig.stylePresets.map((preset) => (
                <SelectItem key={preset} value={preset}>
                  {preset}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {errors.stylePreset ? (
            <p className="text-xs text-destructive">{errors.stylePreset}</p>
          ) : null}
        </div>

        <div className="space-y-2">
          <Label>Camera movement</Label>
          <Select
            value={values.cameraMovement}
            onValueChange={(value) =>
              setValues((prev) => ({ ...prev, cameraMovement: value }))
            }
          >
            <SelectTrigger>
              <SelectValue placeholder="Select camera motion" />
            </SelectTrigger>
            <SelectContent>
              {productConfig.cameraMoves.map((move) => (
                <SelectItem key={move} value={move}>
                  {move}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <div className="space-y-2">
          <Label>Aspect ratio</Label>
          <Select
            value={values.aspectRatio}
            onValueChange={(value) =>
              setValues((prev) => ({ ...prev, aspectRatio: value }))
            }
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {productConfig.aspectRatios.map((ratio) => (
                <SelectItem key={ratio} value={ratio}>
                  {ratio}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
          <Label>Duration</Label>
          <Select
            value={values.duration}
            onValueChange={(value) =>
              setValues((prev) => ({ ...prev, duration: value }))
            }
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {productConfig.durations.map((duration) => (
                <SelectItem key={duration} value={duration}>
                  {duration}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
          <Label>Quality</Label>
          <Select
            value={values.quality}
            onValueChange={(value) =>
              setValues((prev) => ({ ...prev, quality: value }))
            }
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {productConfig.qualities.map((quality) => (
                <SelectItem key={quality} value={quality}>
                  {quality}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="seed">Seed (optional)</Label>
          <Input
            id="seed"
            value={values.seed}
            onChange={(event) =>
              setValues((prev) => ({ ...prev, seed: event.target.value }))
            }
            placeholder="Auto-generate if empty"
          />
        </div>
        {mode === "image" ? (
          <div className="space-y-2">
            <Label htmlFor="imageUpload">Input image (image-to-video)</Label>
            <Input
              id="imageUpload"
              type="file"
              accept="image/*"
              onChange={handleImageChange}
            />
            {imagePreview ? (
              <div className="mt-2 overflow-hidden rounded-xl border border-border/60">
                <img
                  src={imagePreview}
                  alt="Input preview"
                  className="h-32 w-full object-cover"
                />
              </div>
            ) : null}
          </div>
        ) : null}
      </div>

      <Button type="submit" className="w-full" disabled={isSubmitting}>
        {isSubmitting ? "Generating..." : "Generate"}
      </Button>
    </form>
  );
}
