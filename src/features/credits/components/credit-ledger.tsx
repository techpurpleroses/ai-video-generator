import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { CreditsSnapshot } from "@/features/credits/types";
import { routes } from "@/lib/routes";

type CreditLedgerProps = {
  data: CreditsSnapshot;
};

export function CreditLedger({ data }: CreditLedgerProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Ledger</CardTitle>
      </CardHeader>
      <CardContent className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-wide text-muted-foreground">
              <th className="py-2" scope="col">
                Timestamp
              </th>
              <th scope="col">Description</th>
              <th scope="col">Delta</th>
              <th scope="col">Job</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border/60">
            {data.ledger.map((entry) => (
              <tr key={entry.id}>
                <td className="py-3">
                  {new Date(entry.createdAt).toLocaleString()}
                </td>
                <td>{entry.description}</td>
                <td className={entry.delta < 0 ? "text-destructive" : "text-foreground"}>
                  {entry.delta > 0 ? `+${entry.delta}` : entry.delta}
                </td>
                <td>
                  {entry.jobId ? (
                    <Link
                      className="text-accent underline-offset-4 hover:underline"
                      href={`${routes.jobs}/${entry.jobId}`}
                    >
                      View
                    </Link>
                  ) : (
                    "-"
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  );
}
