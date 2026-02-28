#!/bin/bash

# Paqet UI Installation Script
# Quick installation for Linux and macOS
# Usage: bash <(curl -Ls https://raw.githubusercontent.com/meha1999/paqet-ui/main/install.sh)

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            ARCH=$(uname -m)
            if [[ "$ARCH" == "x86_64" ]]; then
                ARCH="amd64"
            fi
            ;;
        Darwin*)
            OS="darwin"
            ARCH=$(uname -m)
            if [[ "$ARCH" == "x86_64" ]]; then
                ARCH="amd64"
            elif [[ "$ARCH" == "arm64" ]]; then
                ARCH="arm64"
            fi
            ;;
        *)
            print_error "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
    print_success "Detected OS: $OS ($ARCH)"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    print_success "curl found"
    
    if ! command -v sqlite3 &> /dev/null; then
        print_warn "sqlite3 not found (may be required)"
    else
        print_success "sqlite3 found"
    fi
}

# Create directories
create_directories() {
    print_info "Creating directories..."
    mkdir -p ~/.paqet-ui
    mkdir -p ~/.paqet-ui/backups
    print_success "Directories created"
}

# Download or build application
install_application() {
    print_info "Installing Paqet UI..."
    
    APP_DIR="$HOME/.local/bin"
    mkdir -p "$APP_DIR"
    
    # Try to download pre-built binary from latest release
    REPO="meha1999/paqet-ui"
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"download_url"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$LATEST_RELEASE" ]; then
        print_warn "No pre-built binary found, building from source..."
        install_from_source
    else
        print_info "Downloading binary..."
        curl -L -o "$APP_DIR/paqet-ui" "$LATEST_RELEASE"
        chmod +x "$APP_DIR/paqet-ui"
        print_success "Binary downloaded to $APP_DIR/paqet-ui"
    fi
    
    # Add to PATH if not already
    if [[ ":$PATH:" != *":$APP_DIR:"* ]]; then
        print_warn "Add $APP_DIR to your PATH or use full path to run paqet-ui"
    fi
}

# Build from source
install_from_source() {
    print_info "Building from source..."
    
    if ! command -v go &> /dev/null; then
        print_error "Go is required to build from source. Please install Go 1.21+"
        print_info "Visit: https://golang.org/dl/"
        exit 1
    fi
    
    # Clone repository
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    print_info "Cloning repository..."
    git clone https://github.com/meha1999/paqet-ui.git
    cd paqet-ui
    
    # Build
    print_info "Building application..."
    go build -o paqet-ui main.go
    
    # Install
    APP_DIR="$HOME/.local/bin"
    mkdir -p "$APP_DIR"
    mv paqet-ui "$APP_DIR/"
    chmod +x "$APP_DIR/paqet-ui"
    
    print_success "Built and installed to $APP_DIR/paqet-ui"
    
    # Cleanup
    cd ~
    rm -rf "$TMPDIR"
}

# Setup systemd service (Linux only)
setup_systemd() {
    if [ "$OS" != "linux" ]; then
        return
    fi
    
    print_info "Setting up systemd service..."
    
    SERVICE_FILE="/etc/systemd/system/paqet-ui.service"
    
    if [ -f "$SERVICE_FILE" ]; then
        print_warn "Service file already exists at $SERVICE_FILE"
        return
    fi
    
    cat > /tmp/paqet-ui.service << 'EOF'
[Unit]
Description=Paqet UI Web Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME

ExecStart=$HOME/.local/bin/paqet-ui -port 2053 -path /panel
Restart=on-failure
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource Limits
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Replace $USER and $HOME with actual values
    sed -i "s|\$USER|$USER|g" /tmp/paqet-ui.service
    sed -i "s|\$HOME|$HOME|g" /tmp/paqet-ui.service
    
    # Install service (requires sudo)
    if sudo -n true 2>/dev/null; then
        sudo mv /tmp/paqet-ui.service "$SERVICE_FILE"
        sudo systemctl daemon-reload
        sudo systemctl enable paqet-ui
        print_success "Systemd service installed"
    else
        print_warn "Systemd service installation requires sudo password"
        if sudo mv /tmp/paqet-ui.service "$SERVICE_FILE"; then
            sudo systemctl daemon-reload
            sudo systemctl enable paqet-ui
            print_success "Systemd service installed"
        else
            print_error "Failed to install systemd service"
            print_info "Move /tmp/paqet-ui.service to $SERVICE_FILE manually with sudo"
        fi
    fi
}

# Start application
start_application() {
    print_info "Starting Paqet UI..."
    
    if [ "$OS" = "linux" ]; then
        if sudo systemctl is-active --quiet paqet-ui; then
            print_success "Paqet UI is already running"
            return
        fi
        
        if sudo -n true 2>/dev/null; then
            sudo systemctl start paqet-ui
        else
            sudo systemctl start paqet-ui
        fi
        print_success "Paqet UI started via systemd"
    else
        # macOS or manual start
        if command -v paqet-ui &> /dev/null; then
            # Start in background
            nohup paqet-ui -port 2053 -path /panel > ~/.paqet-ui/app.log 2>&1 &
            print_success "Paqet UI started in background"
        elif [ -f "$HOME/.local/bin/paqet-ui" ]; then
            nohup "$HOME/.local/bin/paqet-ui" -port 2053 -path /panel > ~/.paqet-ui/app.log 2>&1 &
            print_success "Paqet UI started in background"
        else
            print_error "Could not find paqet-ui executable"
            return 1
        fi
    fi
    
    # Wait for startup
    sleep 2
}

# Display access information
display_access_info() {
    print_success "Installation complete!"
    echo ""
    echo -e "${GREEN}┌─────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│   Paqet UI - Quick Start Guide      │${NC}"
    echo -e "${GREEN}├─────────────────────────────────────┤${NC}"
    echo -e "${GREEN}│${NC} Web Panel:   http://localhost:2053/panel"
    echo -e "${GREEN}│${NC} Default User: admin"
    echo -e "${GREEN}│${NC} Default Pass: admin"
    echo -e "${GREEN}│${NC} Config Dir:   ~/.paqet-ui/"
    echo -e "${GREEN}│${NC} Database:     ~/.paqet-ui/paqet-ui.db"
    echo -e "${GREEN}└─────────────────────────────────────┘${NC}"
    echo ""
    
    echo -e "${YELLOW}⚠  IMPORTANT:${NC} Change the default password immediately!"
    echo "   1. Open http://localhost:2053/panel in your browser"
    echo "   2. Login with admin/admin"
    echo "   3. Go to Settings → User Account"
    echo "   4. Change your password"
    echo ""
    
    if [ "$OS" = "linux" ]; then
        echo "Useful commands:"
        echo "  Check status:   sudo systemctl status paqet-ui"
        echo "  View logs:      sudo journalctl -u paqet-ui -f"
        echo "  Stop service:   sudo systemctl stop paqet-ui"
        echo "  Start service:  sudo systemctl start paqet-ui"
    else
        echo "Useful commands:"
        echo "  View logs:      tail -f ~/.paqet-ui/app.log"
        echo "  Kill process:   pkill -f paqet-ui"
    fi
    echo ""
    
    echo "Documentation:"
    echo "  Installation:   https://github.com/meha1999/paqet-ui/blob/main/INSTALLATION.md"
    echo "  API Reference:  https://github.com/meha1999/paqet-ui/blob/main/API.md"
    echo "  Troubleshooting: https://github.com/meha1999/paqet-ui/blob/main/TROUBLESHOOTING.md"
    echo ""
}

# Main installation flow
main() {
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Paqet UI Installation Script     ║${NC}"
    echo -e "${BLUE}║           v1.0.0                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
    
    detect_os
    check_prerequisites
    create_directories
    install_application
    
    if [ "$OS" = "linux" ]; then
        setup_systemd
        start_application
    else
        print_warn "Manual startup required on macOS"
        print_info "Start with: ~/.local/bin/paqet-ui -port 2053 -path /panel"
    fi
    
    display_access_info
}

# Run main
main
