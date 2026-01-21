"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { toast } from "sonner";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { useLogin } from "@/features/auth/hooks";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ApiError } from "@/lib/api/client";
import { routes } from "@/lib/routes";

const loginSchema = z.object({
  email: z.string().email("Enter a valid email."),
  password: z.string().min(6, "Password must be at least 6 characters."),
});

export default function LoginPage() {
  const router = useRouter();
  const { mutateAsync, isPending } = useLogin();

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const values = {
      email: String(formData.get("email") ?? ""),
      password: String(formData.get("password") ?? ""),
    };
    const result = loginSchema.safeParse(values);
    if (!result.success) {
      toast.error(result.error.errors[0]?.message ?? "Invalid credentials");
      return;
    }
    try {
      await mutateAsync(values);
      router.push(routes.dashboard);
    } catch (error) {
      toast.error(
        error instanceof ApiError ? error.message : "Unable to sign in."
      );
    }
  }

  return (
    <AuthShell
      title="Welcome back"
      description="Log in to access your generation dashboard."
      footer={
        <span>
          No account?{" "}
          <Link href={routes.signup} className="text-foreground underline">
            Create one
          </Link>
        </span>
      }
    >
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input id="email" name="email" type="email" placeholder="you@studio.com" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <Input id="password" name="password" type="password" />
        </div>
        <Button className="w-full" type="submit" disabled={isPending}>
          {isPending ? "Signing in..." : "Sign in"}
        </Button>
        <Link className="block text-center text-sm text-muted-foreground" href={routes.forgotPassword}>
          Forgot password?
        </Link>
      </form>
    </AuthShell>
  );
}
