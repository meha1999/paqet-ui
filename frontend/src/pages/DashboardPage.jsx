import {
  Button,
  Card,
  CardBody,
  CardHeader,
  Chip,
  Spinner,
} from "@heroui/react";
import { useCallback, useEffect, useMemo, useState } from "react";

import api, { extractErrorMessage } from "../api";

function formatBytes(bytes) {
  const value = Number(bytes || 0);
  if (!value) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const idx = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  const normalized = value / Math.pow(1024, idx);
  return `${normalized.toFixed(normalized > 9 ? 0 : 1)} ${units[idx]}`;
}

export default function DashboardPage() {
  const [statusPayload, setStatusPayload] = useState(null);
  const [configs, setConfigs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionLoading, setActionLoading] = useState("");

  const loadData = useCallback(async () => {
    try {
      const [statusRes, configsRes] = await Promise.all([
        api.get("/status"),
        api.get("/configurations"),
      ]);
      setStatusPayload(statusRes.data || {});
      setConfigs(Array.isArray(configsRes.data) ? configsRes.data : []);
      setError("");
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to load dashboard."));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
    const timer = setInterval(loadData, 5000);
    return () => clearInterval(timer);
  }, [loadData]);

  const runtime = statusPayload?.runtime || {};
  const activeConfig = statusPayload?.active_config || null;
  const stats = statusPayload?.stats || {};

  const canStart = useMemo(() => {
    return !runtime.running && (activeConfig?.id || configs[0]?.id);
  }, [runtime.running, activeConfig, configs]);

  async function runAction(action) {
    setActionLoading(action);
    try {
      if (action === "start") {
        const configId = activeConfig?.id || configs[0]?.id;
        if (!configId) {
          setError("Create a configuration first.");
          return;
        }
        await api.post("/runtime/start", { config_id: configId });
      } else if (action === "stop") {
        await api.post("/runtime/stop");
      } else if (action === "restart") {
        const payload = activeConfig?.id ? { config_id: activeConfig.id } : {};
        await api.post("/runtime/restart", payload);
      }

      setError("");
      await loadData();
    } catch (err) {
      setError(extractErrorMessage(err, "Action failed."));
    } finally {
      setActionLoading("");
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Spinner size="lg" />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <p className="text-sm text-default-500">Monitor and control Paqet runtime.</p>
      </div>

      {error ? <p className="text-sm text-danger">{error}</p> : null}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <StatCard title="Active Config" value={activeConfig?.name || "-"} />
        <StatCard title="Total Connections" value={String(stats.total_connections || 0)} />
        <StatCard title="Running" value={runtime.running ? "1" : "0"} />
        <StatCard title="Data Transferred" value={formatBytes(stats.total_bytes_in || 0)} />
      </div>

      <Card>
        <CardHeader className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">Runtime Control</h2>
          <Chip color={runtime.running ? "success" : "default"} variant="flat">
            {runtime.running ? "Running" : "Stopped"}
          </Chip>
        </CardHeader>
        <CardBody className="space-y-4">
          <p className="text-sm text-default-600">
            {activeConfig
              ? `Current: ${activeConfig.name} (${activeConfig.role})`
              : "No active configuration selected."}
          </p>
          <div className="flex flex-wrap gap-2">
            <Button
              color="success"
              onPress={() => runAction("start")}
              isDisabled={!canStart}
              isLoading={actionLoading === "start"}
            >
              Start
            </Button>
            <Button
              color="danger"
              onPress={() => runAction("stop")}
              isDisabled={!runtime.running}
              isLoading={actionLoading === "stop"}
            >
              Stop
            </Button>
            <Button
              color="warning"
              onPress={() => runAction("restart")}
              isDisabled={!runtime.running}
              isLoading={actionLoading === "restart"}
            >
              Restart
            </Button>
          </div>
          <p className="text-xs text-default-500">
            Uptime: {runtime.running ? `${runtime.uptime_seconds || 0}s` : "--"}
          </p>
        </CardBody>
      </Card>
    </div>
  );
}

function StatCard({ title, value }) {
  return (
    <Card>
      <CardBody className="space-y-1">
        <p className="text-xs uppercase tracking-wide text-default-500">{title}</p>
        <p className="text-2xl font-semibold">{value}</p>
      </CardBody>
    </Card>
  );
}
