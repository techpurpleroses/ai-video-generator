import { z } from "zod";

export const generationSchema = z.object({
  prompt: z.string().min(8, "Prompt should be at least 8 characters."),
  negativePrompt: z.string().optional(),
  stylePreset: z.string().min(1, "Select a style preset."),
  aspectRatio: z.string().min(1, "Select an aspect ratio."),
  duration: z.string().min(1, "Select a duration."),
  quality: z.string().min(1, "Select a quality level."),
  cameraMovement: z.string().min(1, "Select a camera movement."),
  seed: z.string().optional(),
});

export type GenerationFormValues = z.infer<typeof generationSchema>;
