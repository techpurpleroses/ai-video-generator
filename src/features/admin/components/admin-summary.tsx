import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

type Summary = {
  users: number;
  jobs: number;
  usageSeconds: number;
  failures: number;
};

export function AdminSummary({ summary }: { summary: Summary }) {
  return (
    <div className="grid gap-4 md:grid-cols-4">
      <Card>
        <CardHeader>
          <CardTitle>Users</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-semibold">{summary.users}</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Jobs</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-semibold">{summary.jobs}</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Usage</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-semibold">{summary.usageSeconds}s</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Failures</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-2xl font-semibold">{summary.failures}</p>
        </CardContent>
      </Card>
    </div>
  );
}
