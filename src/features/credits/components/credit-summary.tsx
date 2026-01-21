import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { CreditsSnapshot } from "@/features/credits/types";

type CreditSummaryProps = {
  data: CreditsSnapshot;
};

export function CreditSummary({ data }: CreditSummaryProps) {
  return (
    <div className="grid gap-4 md:grid-cols-3">
      <Card>
        <CardHeader>
          <CardTitle>Available credits</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-semibold">{data.available}</p>
          <p className="text-xs text-muted-foreground">
            Ready for new generations.
          </p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Reserved</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-semibold">{data.reserved}</p>
          <p className="text-xs text-muted-foreground">
            Allocated to running jobs.
          </p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Holds</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-semibold">{data.holds}</p>
          <p className="text-xs text-muted-foreground">
            Pending approval or retries.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
