import {
  Button,
  Card,
  CardBody,
  CardHeader,
  Input,
} from "@heroui/react";
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import api, { extractErrorMessage } from "../api";

export default function LoginPage() {
  const navigate = useNavigate();
  const [username, setUsername] = useState("admin");
  const [password, setPassword] = useState("admin");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [checkingSession, setCheckingSession] = useState(true);

  useEffect(() => {
    let active = true;

    api
      .get("/status")
      .then(() => {
        if (active) navigate("/dashboard", { replace: true });
      })
      .catch(() => {})
      .finally(() => {
        if (active) setCheckingSession(false);
      });

    return () => {
      active = false;
    };
  }, [navigate]);

  async function onSubmit(event) {
    event.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      await api.post("/auth/login", { username, password });
      navigate("/dashboard", { replace: true });
    } catch (err) {
      setError(extractErrorMessage(err, "Login failed."));
    } finally {
      setIsLoading(false);
    }
  }

  if (checkingSession) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-default-100 p-4">
        <Card className="w-full max-w-md">
          <CardBody className="py-8 text-center text-default-500">
            Checking session...
          </CardBody>
        </Card>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-slate-900 via-slate-800 to-zinc-900 p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="pb-0">
          <div>
            <h1 className="text-xl font-semibold">Paqet UI Login</h1>
            <p className="text-sm text-default-500">Sign in to access the panel.</p>
          </div>
        </CardHeader>
        <CardBody>
          <form onSubmit={onSubmit} className="space-y-4">
            <Input
              label="Username"
              value={username}
              onValueChange={setUsername}
              autoComplete="username"
            />
            <Input
              label="Password"
              type="password"
              value={password}
              onValueChange={setPassword}
              autoComplete="current-password"
            />
            {error ? <p className="text-sm text-danger">{error}</p> : null}
            <Button color="primary" type="submit" isLoading={isLoading} className="w-full">
              Login
            </Button>
          </form>
        </CardBody>
      </Card>
    </div>
  );
}
