.PHONY: help build run test clean install-deps dev docker-build docker-run lint fmt

# Variables
APP_NAME=paqet-ui
VERSION=$(shell git describe --tags --always 2>/dev/null || echo "v1.0.0")
BUILD_TIME=$(shell date -u '+%Y-%m-%d %H:%M:%S')
GIT_COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Build flags
LDFLAGS=-ldflags "-X 'main.Version=$(VERSION)' -X 'main.BuildTime=$(BUILD_TIME)' -X 'main.GitCommit=$(GIT_COMMIT)'"

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build application binary
	@echo "Building $(APP_NAME)..."
	go build $(LDFLAGS) -o bin/$(APP_NAME) main.go
	@echo "✓ Build complete: bin/$(APP_NAME)"

build-linux: ## Build for Linux
	@echo "Building $(APP_NAME) for Linux..."
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o bin/$(APP_NAME)-linux main.go
	@echo "✓ Build complete: bin/$(APP_NAME)-linux"

build-mac: ## Build for macOS
	@echo "Building $(APP_NAME) for macOS..."
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o bin/$(APP_NAME)-mac main.go
	@echo "✓ Build complete: bin/$(APP_NAME)-mac"

build-windows: ## Build for Windows
	@echo "Building $(APP_NAME) for Windows..."
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o bin/$(APP_NAME).exe main.go
	@echo "✓ Build complete: bin/$(APP_NAME).exe"

build-all: build-linux build-mac build-windows ## Build for all platforms
	@echo "✓ All builds complete"

run: ## Run application in development mode
	@echo "Running $(APP_NAME)..."
	go run main.go -port 2053 -path /panel -reset-db

run-prod: build ## Build and run in production mode
	@echo "Running $(APP_NAME) (production)..."
	./bin/$(APP_NAME) -port 2053 -path /panel

dev: ## Run with hot reload (requires air)
	@command -v air >/dev/null 2>&1 || { echo "Installing air..."; go install github.com/cosmtrek/air@latest; }
	air

install-deps: ## Install Go dependencies
	@echo "Installing dependencies..."
	go mod download
	go mod tidy
	@echo "✓ Dependencies installed"

test: ## Run tests
	@echo "Running tests..."
	go test -v -cover ./...

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✓ Coverage report: coverage.html"

bench: ## Run benchmarks
	@echo "Running benchmarks..."
	go test -bench=. -benchmem ./...

lint: ## Run linter
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint..."; go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; }
	golangci-lint run

fmt: ## Format code
	@echo "Formatting code..."
	gofmt -s -w .
	@echo "✓ Code formatted"

vet: ## Run go vet
	@echo "Running go vet..."
	go vet ./...

clean: ## Clean build artifacts and cache
	@echo "Cleaning..."
	rm -rf bin/
	rm -f coverage.out coverage.html
	go clean -cache -testcache
	@echo "✓ Clean complete"

docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -t $(APP_NAME):latest .
	docker tag $(APP_NAME):latest $(APP_NAME):$(VERSION)
	@echo "✓ Docker image built: $(APP_NAME):latest"

docker-run: docker-build ## Build and run Docker container
	@echo "Running Docker container..."
	docker run -d \
		--name $(APP_NAME) \
		-p 2053:2053 \
		-v paqet-ui-data:/home/paqet-ui/.paqet-ui \
		$(APP_NAME):latest
	@echo "✓ Container running: http://localhost:2053/panel"

docker-stop: ## Stop running Docker container
	@echo "Stopping Docker container..."
	docker stop $(APP_NAME) && docker rm $(APP_NAME)
	@echo "✓ Container stopped"

docker-logs: ## View Docker container logs
	docker logs -f $(APP_NAME)

compose-up: ## Start services with docker-compose
	@echo "Starting services..."
	docker-compose up -d
	@echo "✓ Services running: http://localhost:2053/panel"

compose-down: ## Stop services with docker-compose
	@echo "Stopping services..."
	docker-compose down
	@echo "✓ Services stopped"

compose-logs: ## View docker-compose logs
	docker-compose logs -f

reset-db: ## Reset database
	@echo "Resetting database..."
	rm -f ~/.paqet-ui/paqet-ui.db
	@echo "✓ Database reset"

migrate: ## Run database migrations
	@echo "Running migrations..."
	go run main.go -reset-db
	@echo "✓ Migrations complete"

generate: ## Generate code (mocks, etc)
	@echo "Generating code..."
	go generate ./...
	@echo "✓ Code generation complete"

deps-update: ## Update dependencies
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy
	@echo "✓ Dependencies updated"

version: ## Show version information
	@echo "$(APP_NAME) version: $(VERSION)"
	@echo "Build time: $(BUILD_TIME)"
	@echo "Git commit: $(GIT_COMMIT)"

.DEFAULT_GOAL := help
