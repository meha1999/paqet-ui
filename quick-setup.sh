#!/usr/bin/env bash
# Paqet UI Quick Setup - install/update and run as a systemd service
# Usage:
#   sudo bash quick-setup.sh
#   sudo bash <(curl -fsSL https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.sh)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ "$(id -u)" -ne 0 ]]; then
    print_error "Run this installer as root so it can create/manage the systemd service."
    print_error "Example: sudo bash quick-setup.sh"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
    print_error "systemd is required for service mode, but it is not available on this host."
    exit 1
fi

print_info "Setting up Paqet UI..."

REPO_DIR="$HOME/paqet-ui"
DATA_DIR="$HOME/.paqet-ui"
SERVICE_NAME="paqet-ui"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CLI_BIN="/usr/local/bin/paqet-ui"
PORT="${PORT:-2053}"
PAQET_BINARY="${PAQET_BINARY:-paqet}"

if [[ -d "$REPO_DIR/.git" ]]; then
    print_info "Updating existing repository..."
    cd "$REPO_DIR"
    git pull --ff-only
else
    print_info "Cloning repository..."
    rm -rf "$REPO_DIR"
    git clone https://github.com/meha1999/paqet-ui.git "$REPO_DIR"
    cd "$REPO_DIR"
fi
print_success "Repository ready at $REPO_DIR"

if ! command -v python3 >/dev/null 2>&1; then
    print_error "Python 3 is required but not installed."
    exit 1
fi
print_success "$(python3 --version) found"

print_info "Setting up Python environment..."
if [[ ! -d "venv" ]]; then
    python3 -m venv venv
fi
source venv/bin/activate
print_success "Virtual environment activated"

print_info "Installing Python packages..."
python3 -m pip install -q --upgrade pip
python3 -m pip install -q -r requirements.txt
print_success "Backend dependencies installed"

if ! command -v node >/dev/null 2>&1; then
    print_error "Node.js is required to build the React frontend but was not found."
    print_error "Install Node.js LTS from https://nodejs.org"
    exit 1
fi
print_success "Node $(node --version) found"

if ! command -v pnpm >/dev/null 2>&1; then
    if command -v corepack >/dev/null 2>&1; then
        print_info "pnpm not found, enabling via corepack..."
        corepack enable
        corepack prepare pnpm@latest --activate
    fi
fi

if ! command -v pnpm >/dev/null 2>&1; then
    print_error "pnpm is required but was not found."
    print_error "Install pnpm: https://pnpm.io/installation"
    exit 1
fi
print_success "pnpm $(pnpm --version) found"

print_info "Installing frontend packages..."
pnpm --dir frontend install --strict-peer-dependencies=false
print_info "Building React frontend..."
pnpm --dir frontend run build
print_success "Frontend built at $REPO_DIR/frontend/dist"

mkdir -p "$DATA_DIR" "$DATA_DIR/logs"
print_success "Data directory ready at $DATA_DIR"

if command -v "$PAQET_BINARY" >/dev/null 2>&1; then
    print_success "Paqet binary found: $(command -v "$PAQET_BINARY")"
else
    print_warn "Paqet binary not found in PATH."
    print_warn "Install Paqet from https://github.com/hanselime/paqet"
    print_warn "Or set custom path: export PAQET_BINARY=/full/path/to/paqet"
fi

if command -v socat >/dev/null 2>&1; then
    print_success "socat found: $(command -v socat) (server upstream relay available)"
else
    print_warn "socat not found (server upstream relay feature will be unavailable)"
fi

print_info "Creating systemd service: $SERVICE_NAME"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Paqet UI (FastAPI + React)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$REPO_DIR
Environment=PYTHONUNBUFFERED=1
Environment=PORT=$PORT
Environment=PAQET_BINARY=$PAQET_BINARY
ExecStart=$REPO_DIR/venv/bin/python $REPO_DIR/app.py
Restart=always
RestartSec=3
NoNewPrivileges=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

print_info "Installing management command: $CLI_BIN"
cat > "$CLI_BIN" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="$SERVICE_NAME"
SERVICE_FILE="$SERVICE_FILE"
REPO_DIR="$REPO_DIR"
DATA_DIR="$DATA_DIR"

usage() {
    cat <<'USAGE'
Paqet UI service manager

Usage:
  paqet-ui start
  paqet-ui stop
  paqet-ui restart
  paqet-ui status
  paqet-ui logs [lines]
  paqet-ui logs-follow
  paqet-ui info
  paqet-ui uninstall [--purge]

Notes:
  --purge  Also remove the installed repo and data directories
USAGE
}

require_root() {
    if [[ "\$(id -u)" -ne 0 ]]; then
        echo "[ERROR] Run as root (or with sudo)." >&2
        exit 1
    fi
}

panel_port() {
    local port
    port=\$(grep -E '^Environment=PORT=' "\$SERVICE_FILE" 2>/dev/null | head -n1 | cut -d= -f3- || true)
    if [[ -z "\$port" ]]; then
        port="2053"
    fi
    echo "\$port"
}

panel_url() {
    local host
    host=\$(hostname -I 2>/dev/null | awk '{print \$1}' || true)
    if [[ -z "\$host" ]]; then
        host="localhost"
    fi
    echo "http://\$host:\$(panel_port)/panel"
}

cmd="\${1:-help}"

case "\$cmd" in
    start)
        require_root
        systemctl start "\$SERVICE_NAME"
        ;;
    stop)
        require_root
        systemctl stop "\$SERVICE_NAME"
        ;;
    restart)
        require_root
        systemctl restart "\$SERVICE_NAME"
        ;;
    status)
        systemctl --no-pager --full status "\$SERVICE_NAME"
        ;;
    logs)
        lines="\${2:-200}"
        journalctl -u "\$SERVICE_NAME" -n "\$lines" --no-pager
        ;;
    logs-follow)
        journalctl -u "\$SERVICE_NAME" -f
        ;;
    info)
        echo "Service: \$SERVICE_NAME"
        echo "Status: \$(systemctl is-active "\$SERVICE_NAME" 2>/dev/null || echo unknown)"
        echo "Enabled: \$(systemctl is-enabled "\$SERVICE_NAME" 2>/dev/null || echo unknown)"
        echo "Panel URL: \$(panel_url)"
        echo "Repo: \$REPO_DIR"
        echo "Data: \$DATA_DIR"
        echo "Service file: \$SERVICE_FILE"
        ;;
    uninstall)
        require_root
        purge_flag="\${2:-}"
        systemctl stop "\$SERVICE_NAME" 2>/dev/null || true
        systemctl disable "\$SERVICE_NAME" 2>/dev/null || true
        rm -f "\$SERVICE_FILE"
        systemctl daemon-reload
        systemctl reset-failed "\$SERVICE_NAME" 2>/dev/null || true
        rm -f /usr/local/bin/paqet-ui
        if [[ "\$purge_flag" == "--purge" ]]; then
            rm -rf "\$REPO_DIR" "\$DATA_DIR"
            echo "[OK] Service removed and data purged."
        else
            echo "[OK] Service removed. Data kept at \$DATA_DIR."
        fi
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
EOF
chmod +x "$CLI_BIN"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null
systemctl restart "$SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "Service is running and configured to auto-start on boot."
else
    print_error "Service failed to start. Run: journalctl -u $SERVICE_NAME -n 200 --no-pager"
    exit 1
fi

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
if [[ -z "$HOST_IP" ]]; then
    HOST_IP="localhost"
fi

echo
echo "========================================"
echo " Paqet UI Installed as a Service"
echo "========================================"
echo "Panel URL: http://$HOST_IP:$PORT/panel"
echo "Default login: admin / admin"
echo
echo "Service commands:"
echo "  paqet-ui info"
echo "  paqet-ui status"
echo "  paqet-ui logs 200"
echo "  paqet-ui logs-follow"
echo "  paqet-ui restart"
echo "  paqet-ui stop"
echo "  paqet-ui start"
echo "  paqet-ui uninstall"
echo "  paqet-ui uninstall --purge"
echo
echo "This installer now exits after setup. The service keeps running in background."
