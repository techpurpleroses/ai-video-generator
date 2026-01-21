import type { Session } from "@/lib/types";

const mockSession: Session = {
  user: {
    id: "user_01",
    name: "Alex Rivera",
    email: "alex@studio.dev",
    avatarUrl: "",
  },
  plan: "Pro",
};

export function getMockSession(isAuthenticated: boolean) {
  return isAuthenticated ? mockSession : null;
}
