"use client";

import Link from "next/link";
import { useTheme } from "next-themes";
import {
  ChevronDown,
  LogOut,
  Menu,
  Moon,
  Sun,
  User,
} from "lucide-react";
import { routes } from "@/lib/routes";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Sidebar } from "./sidebar";
import { useSession, useLogout } from "@/features/auth/hooks";
import { useCredits } from "@/features/credits/hooks";

export function Topbar() {
  const { data } = useSession();
  const { data: credits } = useCredits();
  const { mutateAsync: logout } = useLogout();
  const { theme, setTheme } = useTheme();

  const user = data?.session?.user;
  const plan = data?.session?.plan ?? "Free";

  return (
    <header className="sticky top-0 z-40 flex items-center gap-3 border-b border-border/60 bg-background/80 px-6 py-4 backdrop-blur">
      <div className="lg:hidden">
        <Dialog>
          <DialogTrigger asChild>
            <Button variant="outline" size="icon" aria-label="Open navigation">
              <Menu className="h-4 w-4" />
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-xs p-0">
            <Sidebar variant="mobile" />
          </DialogContent>
        </Dialog>
      </div>

      <div className="flex flex-1 items-center gap-3">
        <div className="relative w-full max-w-md">
          <Input
            aria-label="Global search"
            placeholder="Search jobs, assets, or prompts"
            className="pl-4"
          />
        </div>
      </div>

      <Badge variant="outline">
        Plan: {plan}
      </Badge>
      <Badge variant="accent">
        Credits: {credits?.available ?? "--"}
      </Badge>

      <Button
        variant="ghost"
        size="icon"
        aria-label="Toggle theme"
        onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
      >
        {theme === "dark" ? (
          <Sun className="h-4 w-4" />
        ) : (
          <Moon className="h-4 w-4" />
        )}
      </Button>

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" className="gap-2">
            <span className="hidden sm:inline">{user?.name ?? "Operator"}</span>
            <ChevronDown className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>Account</DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem asChild>
            <Link href={routes.settings} className="flex items-center gap-2">
              <User className="h-4 w-4" />
              Profile settings
            </Link>
          </DropdownMenuItem>
          <DropdownMenuItem
            className="flex items-center gap-2"
            onClick={() => logout().then(() => (window.location.href = routes.login))}
          >
            <LogOut className="h-4 w-4" />
            Log out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </header>
  );
}
