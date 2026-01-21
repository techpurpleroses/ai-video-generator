"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

type FiltersProps = {
  status: string;
  type: string;
  from: string;
  to: string;
  onChange: (patch: Partial<Record<"status" | "type" | "from" | "to", string>>) => void;
};

export function LibraryFilters({ status, type, from, to, onChange }: FiltersProps) {
  return (
    <div className="grid gap-4 rounded-2xl border border-border/60 bg-card p-4 md:grid-cols-4">
      <div className="space-y-2">
        <Label>Status</Label>
        <Select value={status} onValueChange={(value) => onChange({ status: value })}>
          <SelectTrigger>
            <SelectValue placeholder="All" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="ready">Ready</SelectItem>
            <SelectItem value="processing">Processing</SelectItem>
            <SelectItem value="failed">Failed</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-2">
        <Label>Type</Label>
        <Select value={type} onValueChange={(value) => onChange({ type: value })}>
          <SelectTrigger>
            <SelectValue placeholder="All" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="text-to-video">Text-to-video</SelectItem>
            <SelectItem value="image-to-video">Image-to-video</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-2">
        <Label htmlFor="fromDate">From</Label>
        <Input
          id="fromDate"
          type="date"
          value={from}
          onChange={(event) => onChange({ from: event.target.value })}
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor="toDate">To</Label>
        <Input
          id="toDate"
          type="date"
          value={to}
          onChange={(event) => onChange({ to: event.target.value })}
        />
      </div>
    </div>
  );
}
