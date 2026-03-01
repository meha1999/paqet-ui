import {
  Button,
  Card,
  CardBody,
  CardHeader,
  Chip,
  Divider,
  Input,
  Modal,
  ModalBody,
  ModalContent,
  ModalFooter,
  ModalHeader,
  Select,
  SelectItem,
  Spinner,
  Switch,
  useDisclosure,
} from "@heroui/react";
import { useCallback, useEffect, useMemo, useState } from "react";

import api, { extractErrorMessage } from "../api";
import {
  buildYamlFromForm,
  generateKcpKey,
  getDefaultConfigForm,
  parseYamlToForm,
  validateForm,
} from "../utils/configYaml";

const ROLE_OPTIONS = [
  { key: "server", label: "Server" },
  { key: "client", label: "Client" },
];

function selectedKey(selection) {
  if (!selection || selection === "all") return "";
  const first = Array.from(selection)[0];
  return first ? String(first) : "";
}

function ConfigFields({ form, setForm }) {
  const onValue = (key) => (value) => setForm((prev) => ({ ...prev, [key]: value }));
  const setRole = (keys) => {
    const value = selectedKey(keys) || "server";
    setForm((prev) => {
      const shouldGenerateServerKey = value === "server" && prev.role !== "server";
      return {
        ...prev,
        role: value,
        kcpKey: shouldGenerateServerKey ? generateKcpKey() : prev.kcpKey,
      };
    });
  };

  const kcpLabel = form.role === "client" ? "Server KCP Key" : "KCP Key";

  return (
    <div className="space-y-3">
      <Input
        label="Configuration Name"
        value={form.name}
        onValueChange={onValue("name")}
      />

      <Select
        label="Role"
        disallowEmptySelection
        selectedKeys={form.role ? [form.role] : []}
        onSelectionChange={setRole}
      >
        {ROLE_OPTIONS.map((item) => (
          <SelectItem key={item.key}>{item.label}</SelectItem>
        ))}
      </Select>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <Input label="Network Interface" value={form.interface} onValueChange={onValue("interface")} />
        <Input label="IPv4 Bind Address" value={form.ipv4Addr} onValueChange={onValue("ipv4Addr")} />
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <Input label="Router MAC" value={form.routerMac} onValueChange={onValue("routerMac")} />
        <div className="flex items-end gap-2">
          <Input label={kcpLabel} value={form.kcpKey} onValueChange={onValue("kcpKey")} className="flex-1" />
          {form.role === "server" ? (
            <Button
              variant="flat"
              color="secondary"
              onPress={() => {
                setForm((prev) => ({ ...prev, kcpKey: generateKcpKey() }));
              }}
            >
              Generate
            </Button>
          ) : null}
        </div>
      </div>

      {form.role === "server" ? (
        <div className="space-y-3">
          <Input
            label="Server Listen Address"
            value={form.listenAddr}
            onValueChange={onValue("listenAddr")}
            description={'":9999" means listen on all interfaces on port 9999.'}
          />

          <div className="rounded-lg border border-default-200 p-3">
            <div className="mb-3 flex items-center justify-between gap-2">
              <div>
                <p className="text-sm font-medium">Upstream Relay (Optional)</p>
                <p className="text-xs text-default-500">
                  Accept incoming TCP traffic on this server and forward it to another target using socat.
                </p>
              </div>
              <Switch
                isSelected={Boolean(form.upstreamRelayEnabled)}
                onValueChange={(checked) => {
                  setForm((prev) => ({ ...prev, upstreamRelayEnabled: checked }));
                }}
              />
            </div>

            {form.upstreamRelayEnabled ? (
              <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                <Input
                  label="Forward Listen (Relay)"
                  value={form.upstreamListen}
                  onValueChange={onValue("upstreamListen")}
                  description='Address to accept traffic locally, e.g. "127.0.0.1:10080".'
                />
                <Input
                  label="Forward Target (Relay)"
                  value={form.upstreamTarget}
                  onValueChange={onValue("upstreamTarget")}
                  description='Destination host:port, e.g. "10.10.0.5:443".'
                />
              </div>
            ) : null}
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          <Input label="Server Address" value={form.serverAddr} onValueChange={onValue("serverAddr")} />
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
            <Input label="SOCKS5 Listen" value={form.socks5Listen} onValueChange={onValue("socks5Listen")} />
            <Input label="Forward Listen" value={form.forwardListen} onValueChange={onValue("forwardListen")} />
          </div>
          <Input
            label="Forward Target"
            value={form.forwardTarget}
            onValueChange={onValue("forwardTarget")}
            description="Destination host:port that receives forwarded traffic."
          />
        </div>
      )}
    </div>
  );
}

export default function ConfigurationsPage() {
  const createModal = useDisclosure();
  const editModal = useDisclosure();

  const [configs, setConfigs] = useState([]);
  const [defaults, setDefaults] = useState(null);
  const [createForm, setCreateForm] = useState(getDefaultConfigForm({}, "server", ""));
  const [editForm, setEditForm] = useState(getDefaultConfigForm({}, "server", ""));
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState("");

  const loadConfigs = useCallback(async () => {
    try {
      const response = await api.get("/configurations");
      setConfigs(Array.isArray(response.data) ? response.data : []);
      setError("");
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to load configurations."));
    } finally {
      setIsLoading(false);
    }
  }, []);

  const ensureDefaults = useCallback(async () => {
    if (defaults) return defaults;
    const response = await api.get("/system/default-config");
    const values = response.data || {};
    setDefaults(values);
    return values;
  }, [defaults]);

  useEffect(() => {
    loadConfigs();
  }, [loadConfigs]);

  const hasConfigs = useMemo(() => configs.length > 0, [configs.length]);

  async function openCreateModal() {
    try {
      const values = await ensureDefaults();
      const initial = getDefaultConfigForm(values, "server", "VPS Server");
      initial.kcpKey = generateKcpKey();
      setCreateForm(initial);
      createModal.onOpen();
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to read VPS defaults."));
    }
  }

  async function saveCreate() {
    const validationError = validateForm(createForm);
    if (validationError) {
      setError(validationError);
      return;
    }

    setIsSaving(true);
    try {
      const sidecar =
        createForm.role === "server"
          ? {
              enabled: Boolean(createForm.upstreamRelayEnabled),
              listen: String(createForm.upstreamListen || "").trim(),
              target: String(createForm.upstreamTarget || "").trim(),
            }
          : { enabled: false, listen: "", target: "" };

      await api.post("/configurations", {
        name: createForm.name,
        role: createForm.role,
        config_yaml: buildYamlFromForm(createForm),
        sidecar,
      });
      setError("");
      createModal.onClose();
      await loadConfigs();
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to create configuration."));
    } finally {
      setIsSaving(false);
    }
  }

  async function openEditModal(configId) {
    setError("");
    try {
      const [defaultsValue, configResponse] = await Promise.all([
        ensureDefaults(),
        api.get(`/configurations/${configId}`),
      ]);

      const config = configResponse.data || {};
      const parsed = parseYamlToForm(config.config_yaml || "", defaultsValue, config.role || "server");

      setEditForm({
        ...parsed,
        id: config.id,
        name: config.name || parsed.name,
        role: config.role || parsed.role,
        upstreamRelayEnabled: Boolean(config.sidecar?.enabled),
        upstreamListen: String(config.sidecar?.listen || parsed.upstreamListen || "127.0.0.1:10080"),
        upstreamTarget: String(config.sidecar?.target || parsed.upstreamTarget || ""),
      });

      editModal.onOpen();
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to load configuration details."));
    }
  }

  async function saveEdit() {
    const validationError = validateForm(editForm);
    if (validationError) {
      setError(validationError);
      return;
    }
    if (!editForm.id) {
      setError("Missing configuration id.");
      return;
    }

    setIsSaving(true);
    try {
      const sidecar =
        editForm.role === "server"
          ? {
              enabled: Boolean(editForm.upstreamRelayEnabled),
              listen: String(editForm.upstreamListen || "").trim(),
              target: String(editForm.upstreamTarget || "").trim(),
            }
          : { enabled: false, listen: "", target: "" };

      await api.put(`/configurations/${editForm.id}`, {
        name: editForm.name,
        role: editForm.role,
        config_yaml: buildYamlFromForm(editForm),
        sidecar,
      });
      setError("");
      editModal.onClose();
      await loadConfigs();
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to update configuration."));
    } finally {
      setIsSaving(false);
    }
  }

  async function activateConfig(configId) {
    try {
      await api.patch(`/configurations/${configId}/activate`);
      await loadConfigs();
      setError("");
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to activate configuration."));
    }
  }

  async function deleteConfig(configId) {
    const ok = window.confirm("Delete this configuration?");
    if (!ok) return;

    try {
      await api.delete(`/configurations/${configId}`);
      await loadConfigs();
      setError("");
    } catch (err) {
      setError(extractErrorMessage(err, "Failed to delete configuration."));
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-2xl font-semibold">Configurations</h1>
          <p className="text-sm text-default-500">Create and edit Paqet configuration using form fields.</p>
        </div>
        <Button color="primary" onPress={openCreateModal}>
          New Configuration
        </Button>
      </div>

      {error ? <p className="text-sm text-danger">{error}</p> : null}

      {isLoading ? (
        <div className="flex justify-center py-16">
          <Spinner size="lg" />
        </div>
      ) : null}

      {!isLoading && !hasConfigs ? (
        <Card>
          <CardBody className="py-10 text-center text-default-500">
            No configurations yet.
          </CardBody>
        </Card>
      ) : null}

      {!isLoading && hasConfigs ? (
        <div className="grid grid-cols-1 gap-3">
          {configs.map((config) => (
            <Card key={config.id}>
              <CardHeader className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <h2 className="text-base font-semibold">{config.name}</h2>
                  <Chip size="sm" color={config.role === "client" ? "primary" : "secondary"} variant="flat">
                    {config.role}
                  </Chip>
                  {config.active ? (
                    <Chip size="sm" color="success" variant="flat">
                      active
                    </Chip>
                  ) : null}
                  {config.role === "server" && config.sidecar?.enabled ? (
                    <Chip size="sm" color="warning" variant="flat">
                      relay
                    </Chip>
                  ) : null}
                </div>
                <div className="flex gap-2">
                  <Button size="sm" variant="flat" onPress={() => openEditModal(config.id)}>
                    Edit
                  </Button>
                  <Button size="sm" color="success" variant="flat" onPress={() => activateConfig(config.id)}>
                    Activate
                  </Button>
                  <Button size="sm" color="danger" variant="flat" onPress={() => deleteConfig(config.id)}>
                    Delete
                  </Button>
                </div>
              </CardHeader>
            </Card>
          ))}
        </div>
      ) : null}

      <Modal isOpen={createModal.isOpen} onOpenChange={createModal.onOpenChange} size="3xl" scrollBehavior="inside">
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader>Create New Configuration</ModalHeader>
              <ModalBody>
                <ConfigFields form={createForm} setForm={setCreateForm} />
                <Divider />
                <p className="text-xs text-default-500">
                  YAML is generated automatically and stored when you click Create.
                </p>
              </ModalBody>
              <ModalFooter>
                <Button variant="flat" onPress={onClose}>
                  Cancel
                </Button>
                <Button color="primary" onPress={saveCreate} isLoading={isSaving}>
                  Create
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>

      <Modal isOpen={editModal.isOpen} onOpenChange={editModal.onOpenChange} size="3xl" scrollBehavior="inside">
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader>Edit Configuration</ModalHeader>
              <ModalBody>
                <ConfigFields form={editForm} setForm={setEditForm} />
                <Divider />
                <p className="text-xs text-default-500">
                  YAML is regenerated from the form when you click Save Changes.
                </p>
              </ModalBody>
              <ModalFooter>
                <Button variant="flat" onPress={onClose}>
                  Cancel
                </Button>
                <Button color="primary" onPress={saveEdit} isLoading={isSaving}>
                  Save Changes
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>
    </div>
  );
}
