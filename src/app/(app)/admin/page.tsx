"use client";

import { PageHeader } from "@/components/common/page-header";
import { productConfig } from "@/lib/config/product";
import { AdminSummary } from "@/features/admin/components/admin-summary";
import { useAdminSummary } from "@/features/admin/hooks";
import { EmptyState } from "@/components/common/empty-state";

export default function AdminPage() {
  const enabled = productConfig.features.adminEnabled;
  const { data } = useAdminSummary(enabled);

  if (!enabled) {
    return (
      <div className="space-y-6">
        <PageHeader title="Admin" description="Internal monitoring tools." />
        <EmptyState
          title="Admin disabled"
          description="Enable the admin feature flag in product config to show this view."
        />
      </div>
    );
  }

  if (!data) {
    return <div className="text-sm text-muted-foreground">Loading summary...</div>;
  }

  return (
    <div className="space-y-8">
      <PageHeader title="Admin" description="Internal metrics snapshot." />
      <AdminSummary summary={data} />
    </div>
  );
}
