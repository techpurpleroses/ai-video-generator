"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { toast } from "sonner";
import { AuthShell } from "@/features/auth/components/auth-shell";
import { useSignup } from "@/features/auth/hooks";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ApiError } from "@/lib/api/client";
import { routes } from "@/lib/routes";

const signupSchema = z.object({
  name: z.string().min(2, "Enter your name."),
  email: z.string().email("Enter a valid email."),
  password: z.string().min(6, "Password must be at least 6 characters."),
});

export default function SignupPage() {
  const router = useRouter();
  const { mutateAsync, isPending } = useSignup();

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const values = {
      name: String(formData.get("name") ?? ""),
      email: String(formData.get("email") ?? ""),
      password: String(formData.get("password") ?? ""),
    };
    const result = signupSchema.safeParse(values);
    if (!result.success) {
      toast.error(result.error.errors[0]?.message ?? "Check your details");
      return;
    }
    try {
      await mutateAsync(values);
      router.push(routes.dashboard);
    } catch (error) {
      toast.error(
        error instanceof ApiError ? error.message : "Unable to create account."
      );
    }
  }

  return (
    <AuthShell
      title="Create your account"
      description="Spin up a workspace and start generating."
      footer={
        <span>
          Already have an account?{" "}
          <Link href={routes.login} className="text-foreground underline">
            Log in
          </Link>
        </span>
      }
    >
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div className="space-y-2">
          <Label htmlFor="name">Name</Label>
          <Input id="name" name="name" placeholder="Jane Operator" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input id="email" name="email" type="email" placeholder="you@studio.com" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <Input id="password" name="password" type="password" />
        </div>
        <Button className="w-full" type="submit" disabled={isPending}>
          {isPending ? "Creating..." : "Create account"}
        </Button>
      </form>
    </AuthShell>
  );
}
