#!/bin/bash
# Paqet UI Quick Setup - One Command Installation + Build + Run
# Usage: bash quick-setup.sh
# OR: curl -fsSL https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Step 1: Clone or update repo
print_info "Setting up Paqet UI..."
REPO_DIR="$HOME/paqet-ui"
if [ -d "$REPO_DIR" ]; then
    print_info "Updating existing repository..."
    cd "$REPO_DIR"
    git pull
else
    print_info "Cloning repository..."
    git clone https://github.com/meha1999/paqet-ui.git "$REPO_DIR"
    cd "$REPO_DIR"
fi
print_success "Repository ready at $REPO_DIR"

# Step 2: Check Go
if ! command -v go &> /dev/null; then
    print_error "Go is required but not installed"
    echo "Install from: https://golang.org/dl"
    exit 1
fi
GO_VERSION=$(go version | awk '{print $3}')
print_success "Go $GO_VERSION found"

# Step 3: Build application
print_info "Building application..."
rm -f go.sum
go clean -modcache
go mod tidy
go build -o paqet-ui

if [ ! -f paqet-ui ]; then
    print_error "Build failed"
    exit 1
fi
print_success "Build complete"

# Step 4: Create directories
APP_DIR="$HOME/.local/bin"
mkdir -p "$APP_DIR"
cp paqet-ui "$APP_DIR/"
chmod +x "$APP_DIR/paqet-ui"
print_success "Binary installed to $APP_DIR/paqet-ui"

# Step 5: Create app data directory
mkdir -p "$HOME/.paqet-ui"
print_success "Data directory ready at $HOME/.paqet-ui"

# Step 6: Run application
print_info "Starting Paqet UI..."
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  Paqet UI is Starting${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "📍 URL: http://localhost:2053/panel"
echo "👤 Default username: admin"
echo "🔐 Default password: admin"
echo ""
echo "Database: SQLite (local file)"
echo "Location: $HOME/.paqet-ui/paqet-ui.db"
echo ""
echo "Press CTRL+C to stop"
echo ""

cd "$REPO_DIR"
exec "$APP_DIR/paqet-ui" -port 2053 -path /panel -username admin -password admin
