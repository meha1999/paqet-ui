import yaml from "js-yaml";

export function getDefaultConfigForm(defaults = {}, role = "server", name = "") {
  const generatedKey = generateKcpKey();
  return {
    id: null,
    name: name || `VPS ${role === "client" ? "Client" : "Server"}`,
    role,
    interface: defaults.interface || "eth0",
    ipv4Addr: defaults.ipv4_bind || "0.0.0.0:0",
    routerMac: defaults.router_mac || "00:00:00:00:00:00",
    kcpKey: role === "server" ? generatedKey : defaults.kcp_key || generatedKey,
    serverAddr: defaults.server_addr || "127.0.0.1:9999",
    listenAddr: defaults.listen_addr || ":9999",
    socks5Listen: "127.0.0.1:1080",
    forwardListen: "127.0.0.1:8080",
    forwardTarget: "example.com:80",
  };
}

export function parseYamlToForm(configYaml, defaults = {}, roleFallback = "server") {
  const parsed = safeLoadYaml(configYaml);
  const role = String(parsed?.role || roleFallback || "server").toLowerCase() === "client" ? "client" : "server";

  const form = getDefaultConfigForm(defaults, role);
  form.interface = readPath(parsed, ["network", "interface"], form.interface);
  form.ipv4Addr = readPath(parsed, ["network", "ipv4", "addr"], form.ipv4Addr);
  form.routerMac = readPath(parsed, ["network", "ipv4", "router_mac"], form.routerMac);
  form.kcpKey = readPath(parsed, ["transport", "kcp", "key"], form.kcpKey);
  form.serverAddr = readPath(parsed, ["server", "addr"], form.serverAddr);
  form.listenAddr = readPath(parsed, ["listen", "addr"], form.listenAddr);
  form.socks5Listen = readPath(parsed, ["socks5", 0, "listen"], form.socks5Listen);
  form.forwardListen = readPath(parsed, ["forward", 0, "listen"], form.forwardListen);
  form.forwardTarget = readPath(parsed, ["forward", 0, "target"], form.forwardTarget);
  return form;
}

export function buildYamlFromForm(form) {
  const role = String(form.role || "server").toLowerCase() === "client" ? "client" : "server";

  if (role === "server") {
    return `role: "server"

log:
  level: "info"

listen:
  addr: "${escapeDoubleQuote(form.listenAddr)}"

network:
  interface: "${escapeDoubleQuote(form.interface)}"
  ipv4:
    addr: "${escapeDoubleQuote(form.ipv4Addr)}"
    router_mac: "${escapeDoubleQuote(form.routerMac)}"

transport:
  protocol: "kcp"
  kcp:
    block: "aes"
    key: "${escapeDoubleQuote(form.kcpKey)}"
`;
  }

  return `role: "client"

log:
  level: "info"

socks5:
  - listen: "${escapeDoubleQuote(form.socks5Listen)}"
    username: ""
    password: ""

forward:
  - listen: "${escapeDoubleQuote(form.forwardListen)}"
    target: "${escapeDoubleQuote(form.forwardTarget)}"
    protocol: "tcp"

network:
  interface: "${escapeDoubleQuote(form.interface)}"
  ipv4:
    addr: "${escapeDoubleQuote(form.ipv4Addr)}"
    router_mac: "${escapeDoubleQuote(form.routerMac)}"

server:
  addr: "${escapeDoubleQuote(form.serverAddr)}"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    block: "aes"
    key: "${escapeDoubleQuote(form.kcpKey)}"
`;
}

export function validateForm(form) {
  if (!form.name || !form.role) return "Set configuration name and role.";
  if (!form.interface || !form.ipv4Addr || !form.kcpKey) return "Fill interface, IPv4 bind address, and KCP key.";
  if (form.role === "server" && !form.listenAddr) return "Set server listen address.";
  if (form.role === "client" && !form.serverAddr) return "Set server address for client mode.";
  return "";
}

export function generateKcpKey(length = 32) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const size = Math.max(16, Math.min(64, Number(length) || 32));
  let output = "";

  if (globalThis.crypto && typeof globalThis.crypto.getRandomValues === "function") {
    const random = new Uint8Array(size);
    globalThis.crypto.getRandomValues(random);
    for (let i = 0; i < size; i += 1) {
      output += chars[random[i] % chars.length];
    }
    return output;
  }

  for (let i = 0; i < size; i += 1) {
    output += chars[Math.floor(Math.random() * chars.length)];
  }
  return output;
}

function safeLoadYaml(text) {
  if (!text) return {};
  try {
    const parsed = yaml.load(text);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function readPath(source, path, fallback) {
  let current = source;
  for (const key of path) {
    if (current == null || current[key] == null) return fallback;
    current = current[key];
  }
  return current == null ? fallback : String(current);
}

function escapeDoubleQuote(text) {
  return String(text || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}
