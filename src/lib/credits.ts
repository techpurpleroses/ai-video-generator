export type CreditEstimateInput = {
  duration: string;
  quality: string;
  aspectRatio: string;
};

const durationMultiplier: Record<string, number> = {
  "8s": 1,
  "16s": 1.8,
  "32s": 3.4,
};

const qualityMultiplier: Record<string, number> = {
  Draft: 0.6,
  Standard: 1,
  Ultra: 1.6,
};

const ratioMultiplier: Record<string, number> = {
  "16:9": 1,
  "9:16": 1.1,
  "1:1": 0.9,
};

export function estimateCredits(input: CreditEstimateInput) {
  const base = 18;
  const duration = durationMultiplier[input.duration] ?? 1;
  const quality = qualityMultiplier[input.quality] ?? 1;
  const ratio = ratioMultiplier[input.aspectRatio] ?? 1;
  return Math.round(base * duration * quality * ratio);
}
