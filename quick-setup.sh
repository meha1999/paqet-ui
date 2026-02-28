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

# Step 5: Create app directory
APP_DIR="$HOME/.local/bin"
mkdir -p "$APP_DIR"
print_success "Application directory ready"

# Step 6: Create data directory
mkdir -p "$HOME/.paqet-ui"
print_success "Data directory ready at $HOME/.paqet-ui"

# Step 7: Run application
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
echo "Database: SQLite (local file)"
echo "Location: $HOME/.paqet-ui/paqet-ui.db"
echo ""
echo "Press CTRL+C to stop"
echo ""

python3 app.py
