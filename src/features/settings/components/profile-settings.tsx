"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function ProfileSettings() {
  return (
    <Card>
      <CardContent className="space-y-4 p-6">
        <div className="space-y-2">
          <Label htmlFor="profileName">Name</Label>
          <Input id="profileName" placeholder="Jane Operator" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="profileEmail">Email</Label>
          <Input id="profileEmail" type="email" placeholder="jane@studio.com" />
        </div>
        <Button className="w-fit">Save changes</Button>
      </CardContent>
    </Card>
  );
}
