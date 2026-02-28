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

# Step 3: Check PostgreSQL
if ! command -v psql &> /dev/null; then
    print_warn "PostgreSQL client not found. Using Docker PostgreSQL..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required for PostgreSQL"
        echo "Install Docker from: https://docker.com"
        exit 1
    fi
    
    # Start PostgreSQL container
    print_info "Starting PostgreSQL container..."
    docker ps | grep -q paqet-postgres && docker stop paqet-postgres || true
    docker container exists paqet-postgres 2>/dev/null && docker rm paqet-postgres || true
    
    docker run -d \
        --name paqet-postgres \
        -e POSTGRES_USER=paqet \
        -e POSTGRES_PASSWORD=paqet \
        -e POSTGRES_DB=paqet_ui \
        -p 5432:5432 \
        postgres:15-alpine
    
    print_success "PostgreSQL container started"
    sleep 3
    echo "export DATABASE_USER=paqet"
    echo "export DATABASE_PASSWORD=paqet"
    echo "export DATABASE_HOST=localhost"
    echo "export DATABASE_PORT=5432"
    echo "export DATABASE_NAME=paqet_ui"
else
    print_success "PostgreSQL found"
fi

# Step 4: Setup database credentials
print_info "Configuring database connection..."
export DATABASE_USER="${DATABASE_USER:-paqet}"
export DATABASE_PASSWORD="${DATABASE_PASSWORD:-paqet}"
export DATABASE_HOST="${DATABASE_HOST:-localhost}"
export DATABASE_PORT="${DATABASE_PORT:-5432}"
export DATABASE_NAME="${DATABASE_NAME:-paqet_ui}"

# Step 5: Clean and build
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

# Step 6: Create app directory and copy binary
APP_DIR="$HOME/.local/bin"
mkdir -p "$APP_DIR"
cp paqet-ui "$APP_DIR/"
chmod +x "$APP_DIR/paqet-ui"

# Step 7: Set up .env file
ENV_FILE="$HOME/.paqet-ui/.env"
mkdir -p "$HOME/.paqet-ui"
cat > "$ENV_FILE" << EOF
DATABASE_USER=$DATABASE_USER
DATABASE_PASSWORD=$DATABASE_PASSWORD
DATABASE_HOST=$DATABASE_HOST
DATABASE_PORT=$DATABASE_PORT
DATABASE_NAME=$DATABASE_NAME
EOF
chmod 600 "$ENV_FILE"
print_success "Environment configured at $ENV_FILE"

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
echo "Database: PostgreSQL"
echo "User: $DATABASE_USER"
echo "Host: $DATABASE_HOST:$DATABASE_PORT"
echo ""
echo "Press CTRL+C to stop"
echo ""

cd "$REPO_DIR"
exec "$APP_DIR/paqet-ui" -port 2053 -path /panel -username admin -password admin
