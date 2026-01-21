import { Card, CardContent } from "@/components/ui/card";
import { estimateCredits } from "@/lib/credits";

type CostEstimatorProps = {
  duration: string;
  quality: string;
  aspectRatio: string;
};

export function CostEstimator({
  duration,
  quality,
  aspectRatio,
}: CostEstimatorProps) {
  const credits = estimateCredits({ duration, quality, aspectRatio });

  return (
    <Card>
      <CardContent className="space-y-2 p-4">
        <p className="text-xs uppercase tracking-wide text-muted-foreground">
          Estimated cost
        </p>
        <p className="text-2xl font-semibold">{credits} credits</p>
        <p className="text-xs text-muted-foreground">
          Estimate based on duration and quality presets.
        </p>
      </CardContent>
    </Card>
  );
}
