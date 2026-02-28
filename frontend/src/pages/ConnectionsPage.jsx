import {
  Card,
  CardBody,
  CardHeader,
  Chip,
  Spinner,
  Table,
  TableBody,
  TableCell,
  TableColumn,
  TableHeader,
  TableRow,
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

function statusColor(status) {
  if (status === "running") return "success";
  if (status === "stopped") return "default";
  if (status === "error") return "danger";
  return "warning";
}

export default function ConnectionsPage() {
  const [connections, setConnections] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState("");

  const loadConnections = useCallback(async () => {
    try {
      const response = await api.get("/connections");
      const rows = Array.isArray(response.data) ? response.data : [];
      setConnections(rows);
      setError("");
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to load connections."));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadConnections();
    const timer = setInterval(loadConnections, 5000);
    return () => clearInterval(timer);
  }, [loadConnections]);

  const summary = useMemo(() => {
    const total = connections.length;
    const running = connections.filter((item) => item.status === "running").length;
    const stopped = connections.filter((item) => item.status === "stopped").length;
    const totalBytes = connections.reduce(
      (sum, item) => sum + Number(item.bytes_in || 0) + Number(item.bytes_out || 0),
      0,
    );

    return { total, running, stopped, totalBytes };
  }, [connections]);

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold">Connections</h1>
        <p className="text-sm text-default-500">Live connection activity and traffic usage.</p>
      </div>

      {error ? <p className="text-sm text-danger">{error}</p> : null}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <StatCard label="Total" value={summary.total} />
        <StatCard label="Running" value={summary.running} />
        <StatCard label="Stopped" value={summary.stopped} />
        <StatCard label="Data" value={formatBytes(summary.totalBytes)} />
      </div>

      <Card>
        <CardHeader className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">Connection List</h2>
        </CardHeader>
        <CardBody>
          {isLoading ? (
            <div className="flex justify-center py-16">
              <Spinner size="lg" />
            </div>
          ) : (
            <Table aria-label="connections table">
              <TableHeader>
                <TableColumn>ID</TableColumn>
                <TableColumn>CONFIG</TableColumn>
                <TableColumn>STATUS</TableColumn>
                <TableColumn>BYTES IN</TableColumn>
                <TableColumn>BYTES OUT</TableColumn>
                <TableColumn>LAST ACTIVITY</TableColumn>
              </TableHeader>
              <TableBody emptyContent="No connections found." items={connections}>
                {(item) => (
                  <TableRow key={item.id}>
                    <TableCell>{item.id}</TableCell>
                    <TableCell>{item.configuration?.name || `Config #${item.config_id}`}</TableCell>
                    <TableCell>
                      <Chip size="sm" color={statusColor(item.status)} variant="flat">
                        {item.status || "unknown"}
                      </Chip>
                    </TableCell>
                    <TableCell>{formatBytes(item.bytes_in)}</TableCell>
                    <TableCell>{formatBytes(item.bytes_out)}</TableCell>
                    <TableCell>
                      {item.last_activity_at ? new Date(item.last_activity_at).toLocaleString() : "-"}
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </CardBody>
      </Card>
    </div>
  );
}

function StatCard({ label, value }) {
  return (
    <Card>
      <CardBody className="space-y-1">
        <p className="text-xs uppercase tracking-wide text-default-500">{label}</p>
        <p className="text-2xl font-semibold">{value}</p>
      </CardBody>
    </Card>
  );
}
