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
  useDisclosure,
} from "@heroui/react";
import { useCallback, useEffect, useMemo, useState } from "react";

import api, { extractErrorMessage } from "../api";
import {
  buildYamlFromForm,
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
    setForm((prev) => ({ ...prev, role: value }));
  };

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
        <Input label="KCP Key" value={form.kcpKey} onValueChange={onValue("kcpKey")} />
      </div>

      {form.role === "server" ? (
        <Input label="Server Listen Address" value={form.listenAddr} onValueChange={onValue("listenAddr")} />
      ) : (
        <div className="space-y-3">
          <Input label="Server Address" value={form.serverAddr} onValueChange={onValue("serverAddr")} />
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
            <Input label="SOCKS5 Listen" value={form.socks5Listen} onValueChange={onValue("socks5Listen")} />
            <Input label="Forward Listen" value={form.forwardListen} onValueChange={onValue("forwardListen")} />
          </div>
          <Input label="Forward Target" value={form.forwardTarget} onValueChange={onValue("forwardTarget")} />
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
      setCreateForm(getDefaultConfigForm(values, "server", "VPS Server"));
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
      await api.post("/configurations", {
        name: createForm.name,
        role: createForm.role,
        config_yaml: buildYamlFromForm(createForm),
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
      await api.put(`/configurations/${editForm.id}`, {
        name: editForm.name,
        role: editForm.role,
        config_yaml: buildYamlFromForm(editForm),
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
