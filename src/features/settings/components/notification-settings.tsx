"use client";

import { Card, CardContent } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";

export function NotificationSettings() {
  return (
    <Card>
      <CardContent className="space-y-4 p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-medium">Job completed</p>
            <p className="text-sm text-muted-foreground">
              Notify me when a render finishes.
            </p>
          </div>
          <Switch aria-label="Job completed notifications" />
        </div>
        <div className="flex items-center justify-between">
          <div>
            <p className="font-medium">Credit threshold</p>
            <p className="text-sm text-muted-foreground">
              Alert me when credits are low.
            </p>
          </div>
          <Switch aria-label="Low credit notifications" />
        </div>
      </CardContent>
    </Card>
  );
}
