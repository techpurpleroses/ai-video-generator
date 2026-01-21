import type { ReactNode } from "react";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { cn } from "@/lib/utils";

type AuthShellProps = {
  title: string;
  description?: string;
  children: ReactNode;
  footer?: ReactNode;
  className?: string;
};

export function AuthShell({
  title,
  description,
  children,
  footer,
  className,
}: AuthShellProps) {
  return (
    <Card className={cn("w-full max-w-md border-border/70 bg-card/90", className)}>
      <CardHeader>
        <h1 className="text-2xl font-semibold font-display">{title}</h1>
        {description ? (
          <p className="text-sm text-muted-foreground">{description}</p>
        ) : null}
      </CardHeader>
      <CardContent className="space-y-6">
        {children}
        {footer ? <div className="pt-2 text-sm text-muted-foreground">{footer}</div> : null}
      </CardContent>
    </Card>
  );
}
