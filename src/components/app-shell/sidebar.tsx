"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Sparkles,
  LayoutGrid,
  Video,
  Layers,
  CreditCard,
  Settings,
  Shield,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { routes } from "@/lib/routes";
import { productConfig } from "@/lib/config/product";
import { Button } from "@/components/ui/button";

const navItems = [
  { label: "Dashboard", href: routes.dashboard, icon: LayoutGrid },
  { label: "Generate", href: routes.generate, icon: Sparkles },
  { label: "Jobs", href: routes.jobs, icon: Video },
  { label: "Library", href: routes.library, icon: Layers },
  { label: "Credits", href: routes.credits, icon: CreditCard },
  { label: "Settings", href: routes.settings, icon: Settings },
  {
    label: "Admin",
    href: routes.admin,
    icon: Shield,
    enabled: productConfig.features.adminEnabled,
  },
];

export function Sidebar({
  variant = "desktop",
  className,
}: {
  variant?: "desktop" | "mobile";
  className?: string;
}) {
  const pathname = usePathname();

  return (
    <aside
      className={cn(
        variant === "mobile"
          ? "flex w-full flex-col bg-card px-4 py-6"
          : "hidden h-screen w-64 flex-col border-r border-border/60 bg-card px-4 py-6 lg:flex",
        className
      )}
    >
      <div className="flex items-center gap-3 px-2">
        <div className="grid h-10 w-10 place-items-center rounded-2xl bg-primary text-primary-foreground">
          <span className="text-sm font-semibold">AV</span>
        </div>
        <div>
          <p className="text-sm font-semibold">AI Video Generator</p>
          <p className="text-xs text-muted-foreground">Template preview</p>
        </div>
      </div>

      <nav className="mt-8 flex flex-1 flex-col gap-1">
        {navItems
          .filter((item) => item.enabled !== false)
          .map((item) => {
          const active =
            pathname === item.href || pathname.startsWith(`${item.href}/`);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition",
                active
                  ? "bg-secondary text-foreground"
                  : "text-muted-foreground hover:bg-secondary/70 hover:text-foreground"
              )}
            >
              <Icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="rounded-2xl border border-border/60 bg-muted/30 p-4 text-xs text-muted-foreground">
        <p className="font-semibold text-foreground">Need more credits?</p>
        <p className="mt-1">
          Upgrade anytime to unlock higher caps and faster queues.
        </p>
        <Button asChild className="mt-3 h-9 w-full" size="sm">
          <Link href={routes.billing}>View plans</Link>
        </Button>
      </div>
    </aside>
  );
}
