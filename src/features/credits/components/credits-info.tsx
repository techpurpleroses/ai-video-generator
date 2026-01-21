import { Card, CardContent } from "@/components/ui/card";

export function CreditsInfo() {
  return (
    <Card>
      <CardContent className="space-y-2 p-6 text-sm text-muted-foreground">
        <h3 className="text-base font-semibold text-foreground">
          How credits work
        </h3>
        <p>
          Credits are estimated before each generation based on duration,
          quality, and aspect ratio. Running jobs reserve credits until the
          render completes.
        </p>
        <p>
          If a job fails or is canceled, reserved credits are returned
          automatically. You can always review usage in the ledger.
        </p>
      </CardContent>
    </Card>
  );
}
