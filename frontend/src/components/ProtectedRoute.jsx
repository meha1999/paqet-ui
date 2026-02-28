import { Card, CardBody, Spinner } from "@heroui/react";
import { useEffect, useState } from "react";
import { Navigate } from "react-router-dom";

import api from "../api";

export default function ProtectedRoute({ children }) {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthed, setIsAuthed] = useState(false);

  useEffect(() => {
    let active = true;

    api
      .get("/status")
      .then(() => {
        if (active) setIsAuthed(true);
      })
      .catch(() => {
        if (active) setIsAuthed(false);
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });

    return () => {
      active = false;
    };
  }, []);

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <Card className="w-full max-w-sm">
          <CardBody className="flex items-center justify-center gap-3 py-10">
            <Spinner size="lg" />
            <p className="text-sm text-default-500">Checking session...</p>
          </CardBody>
        </Card>
      </div>
    );
  }

  if (!isAuthed) {
    return <Navigate to="/login" replace />;
  }

  return children;
}
