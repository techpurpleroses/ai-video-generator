"use client";

import { Card, CardContent } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";

export function PrivacySettings() {
  return (
    <Card>
      <CardContent className="space-y-4 p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-medium">Private mode</p>
            <p className="text-sm text-muted-foreground">
              When enabled, prompts are not stored after completion.
            </p>
          </div>
          <Switch aria-label="Private mode" />
        </div>
        <div>
          <p className="font-medium">Auto-delete outputs</p>
          <p className="text-sm text-muted-foreground">
            Remove generated outputs after a set number of days.
          </p>
          <div className="mt-3 max-w-xs">
            <Select defaultValue="30">
              <SelectTrigger>
                <SelectValue placeholder="Select duration" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="7">After 7 days</SelectItem>
                <SelectItem value="30">After 30 days</SelectItem>
                <SelectItem value="90">After 90 days</SelectItem>
                <SelectItem value="never">Never auto-delete</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
