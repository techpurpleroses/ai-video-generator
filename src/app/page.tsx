import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { routes } from "@/lib/routes";

export default function Home() {
  return (
    <div className="min-h-screen">
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-6 py-6">
        <div className="flex items-center gap-3">
          <div className="grid h-10 w-10 place-items-center rounded-2xl bg-primary text-primary-foreground">
            <span className="text-sm font-semibold">AV</span>
          </div>
          <div>
            <p className="text-sm font-semibold">AI Video Generator</p>
            <p className="text-xs text-muted-foreground">Template preview</p>
          </div>
        </div>
        <div className="hidden items-center gap-4 text-sm md:flex">
          <a className="text-muted-foreground hover:text-foreground" href="#features">
            Features
          </a>
          <a className="text-muted-foreground hover:text-foreground" href="#modules">
            Modules
          </a>
        </div>
        <Button asChild size="sm">
          <Link href={routes.login}>Open dashboard</Link>
        </Button>
      </header>

      <main className="mx-auto w-full max-w-6xl px-6 pb-16">
        <section className="grid gap-12 rounded-3xl border border-border/60 bg-card/80 px-8 py-14 shadow-[var(--shadow)] lg:grid-cols-[1.2fr_0.8fr]">
          <div className="space-y-5">
            <Badge variant="outline">Production-grade UI kit</Badge>
            <h1 className="text-4xl font-semibold font-display leading-tight sm:text-5xl">
              A minimal, premium template for AI video products.
            </h1>
            <p className="text-base text-muted-foreground">
              Ship generation workflows, job tracking, billing, and media
              library UI with mock APIs ready to swap for your backend.
            </p>
            <div className="flex flex-wrap gap-3">
              <Button asChild>
                <Link href={routes.dashboard}>Go to app</Link>
              </Button>
              <Button asChild variant="outline">
                <Link href="#features">View features</Link>
              </Button>
            </div>
          </div>
          <div className="space-y-4 rounded-2xl border border-border/60 bg-background p-6">
            <div className="space-y-2">
              <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">
                Preview
              </p>
              <p className="text-lg font-semibold">Latest render batch</p>
            </div>
            <div className="space-y-3">
              {[
                "Neon skyline, 16s, 4 variants",
                "Studio spin, 8s, 1080p",
                "Ocean drone pass, queued",
              ].map((item) => (
                <div
                  key={item}
                  className="rounded-xl border border-border/60 bg-card px-4 py-3 text-sm"
                >
                  {item}
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="features" className="mt-14 grid gap-4 md:grid-cols-3">
          {[
            "Generation studio with tabs and presets",
            "Job queue with retries and progress",
            "Credits, billing, and usage summaries",
            "Media library with filters and modal view",
            "Settings for privacy and security",
            "Admin overview (feature-flagged)",
          ].map((feature) => (
            <div
              key={feature}
              className="rounded-2xl border border-border/60 bg-card p-5 text-sm text-muted-foreground"
            >
              {feature}
            </div>
          ))}
        </section>

        <section id="modules" className="mt-14 rounded-2xl border border-border/60 bg-card p-6">
          <h2 className="text-xl font-semibold">Reusable modules</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Auth, video generation, jobs, library, credits, and billing are split
            into feature folders with adapters and typed hooks.
          </p>
        </section>
      </main>
    </div>
  );
}
