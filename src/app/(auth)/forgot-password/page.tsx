"use client";

import Link from "next/link";
import { z } from "zod";
import { toast } from "sonner";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { useForgotPassword } from "@/features/auth/hooks";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ApiError } from "@/lib/api/client";
import { routes } from "@/lib/routes";

const schema = z.object({
  email: z.string().email("Enter a valid email."),
});

export default function ForgotPasswordPage() {
  const { mutateAsync, isPending } = useForgotPassword();

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const values = { email: String(formData.get("email") ?? "") };
    const result = schema.safeParse(values);
    if (!result.success) {
      toast.error(result.error.errors[0]?.message ?? "Invalid email");
      return;
    }
    try {
      await mutateAsync(values);
      toast.success("Password reset link sent.");
    } catch (error) {
      toast.error(
        error instanceof ApiError ? error.message : "Unable to send reset link."
      );
    }
  }

  return (
    <AuthShell
      title="Reset your password"
      description="We will send a recovery link to your email."
      footer={
        <span>
          Remember your password?{" "}
          <Link href={routes.login} className="text-foreground underline">
            Back to login
          </Link>
        </span>
      }
    >
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input id="email" name="email" type="email" placeholder="you@studio.com" />
        </div>
        <Button className="w-full" type="submit" disabled={isPending}>
          {isPending ? "Sending..." : "Send reset link"}
        </Button>
      </form>
    </AuthShell>
  );
}
