import { apiFetch } from "@/lib/api/client";
import type {
  AuthResponse,
  ForgotPasswordPayload,
  LoginPayload,
  SignupPayload,
} from "./types";

export async function fetchSession(): Promise<AuthResponse> {
  return apiFetch<AuthResponse>("/api/auth/session");
}

export async function login(payload: LoginPayload): Promise<AuthResponse> {
  return apiFetch<AuthResponse>("/api/auth/session", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function signup(payload: SignupPayload): Promise<AuthResponse> {
  return apiFetch<AuthResponse>("/api/auth/signup", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function logout(): Promise<{ ok: boolean }> {
  return apiFetch<{ ok: boolean }>("/api/auth/logout", { method: "POST" });
}

export async function forgotPassword(
  payload: ForgotPasswordPayload
): Promise<{ ok: boolean }> {
  return apiFetch<{ ok: boolean }>("/api/auth/forgot-password", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
