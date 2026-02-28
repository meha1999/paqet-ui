import { Button, Card, CardBody, CardHeader, Divider } from "@heroui/react";

export default function SettingsPage() {
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Settings</h1>
        <p className="text-sm text-default-500">Panel and account operations.</p>
      </div>

      <Card>
        <CardHeader>
          <h2 className="text-lg font-semibold">Session</h2>
        </CardHeader>
        <CardBody className="space-y-4">
          <p className="text-sm text-default-600">
            Session authentication is enforced on all panel pages and API endpoints.
          </p>
          <Divider />
          <div className="flex flex-wrap gap-2">
            <Button
              color="danger"
              variant="flat"
              onPress={() => {
                window.location.href = "/panel/logout";
              }}
            >
              Logout
            </Button>
          </div>
        </CardBody>
      </Card>
    </div>
  );
}
