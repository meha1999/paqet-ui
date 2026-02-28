#!/bin/bash
# Paqet UI Quick Setup - One Command Installation + Run
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

# Step 2: Check Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed"
    echo "Install from: https://python.org"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
print_success "$PYTHON_VERSION found"

# Step 3: Create virtual environment
print_info "Setting up Python environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
print_success "Virtual environment activated"

# Step 4: Install dependencies
print_info "Installing Python packages..."
pip install -q --upgrade pip
pip install -q -r requirements.txt
print_success "Dependencies installed"

# Step 5: Check Node.js and pnpm for React frontend
if ! command -v node &> /dev/null; then
    print_error "Node.js is required to build the React frontend but was not found"
    print_error "Install Node.js LTS: https://nodejs.org"
    exit 1
fi
print_success "Node $(node --version) found"

if ! command -v pnpm &> /dev/null; then
    if command -v corepack &> /dev/null; then
        print_info "pnpm not found, enabling via corepack..."
        corepack enable
        corepack prepare pnpm@latest --activate
    fi
fi

if ! command -v pnpm &> /dev/null; then
    print_error "pnpm is required but was not found"
    print_error "Install pnpm: https://pnpm.io/installation"
    exit 1
fi
print_success "pnpm $(pnpm --version) found"

print_info "Installing frontend packages..."
pnpm --dir frontend install --strict-peer-dependencies=false
print_info "Building React frontend..."
pnpm --dir frontend run build
print_success "Frontend built at $REPO_DIR/frontend/dist"

# Step 6: Create data directory
mkdir -p "$HOME/.paqet-ui"
print_success "Data directory ready at $HOME/.paqet-ui"

# Step 7: Check Paqet binary
PAQET_BINARY="${PAQET_BINARY:-paqet}"
if command -v "$PAQET_BINARY" >/dev/null 2>&1; then
    print_success "Paqet binary found: $(command -v "$PAQET_BINARY")"
else
    print_warn "Paqet binary not found in PATH"
    print_warn "Install Paqet from https://github.com/hanselime/paqet"
    print_warn "Or set custom path: export PAQET_BINARY=/full/path/to/paqet"
fi

# Step 8: Run application
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
echo "Backend: Python (FastAPI)"
echo "Frontend: React + HeroUI"
echo "Runtime: Paqet command = $PAQET_BINARY run -c <config>"
echo "Database: SQLite (local file)"
echo "Location: $HOME/.paqet-ui/paqet-ui.db"
echo ""
echo "Press CTRL+C to stop"
echo ""

python3 app.py
