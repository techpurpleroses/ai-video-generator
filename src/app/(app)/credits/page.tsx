"use client";

import { PageHeader } from "@/components/common/page-header";
import { useCredits } from "@/features/credits/hooks";
import { CreditSummary } from "@/features/credits/components/credit-summary";
import { CreditLedger } from "@/features/credits/components/credit-ledger";
import { CreditsInfo } from "@/features/credits/components/credits-info";

export default function CreditsPage() {
  const { data } = useCredits();

  if (!data) {
    return <div className="text-sm text-muted-foreground">Loading credits...</div>;
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Credits"
        description="Track balances, holds, and usage history."
      />
      <CreditSummary data={data} />
      <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
        <CreditLedger data={data} />
        <CreditsInfo />
      </div>
    </div>
  );
}
