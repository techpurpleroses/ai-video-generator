import type { ReactNode } from "react";
import { Sidebar } from "./sidebar";
import { Topbar } from "./topbar";

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="flex">
        <Sidebar />
        <div className="min-h-screen flex-1">
          <Topbar />
          <main className="px-6 py-8">{children}</main>
        </div>
      </div>
    </div>
  );
}
