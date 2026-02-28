# Paqet UI Quick Setup - One Command Installation + Build + Run (Windows)
# Usage: powershell -ExecutionPolicy Bypass -Command "iex(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.ps1')"

$ErrorActionPreference = "Stop"

# Colors
$Colors = @{
    Blue   = "`e[34m"
    Green  = "`e[32m"
    Yellow = "`e[33m"
    Red    = "`e[31m"
    Reset  = "`e[0m"
}

function Write-Info { Write-Host "$($Colors.Blue)ℹ$($Colors.Reset) $args" }
function Write-Success { Write-Host "$($Colors.Green)✓$($Colors.Reset) $args" }
function Write-Warn { Write-Host "$($Colors.Yellow)⚠$($Colors.Reset) $args" }
function Write-Error { Write-Host "$($Colors.Red)✗$($Colors.Reset) $args" }

# Step 1: Clone or update repo
Write-Info "Setting up Paqet UI..."
$RepoDir = "$Home\paqet-ui"
if (Test-Path $RepoDir) {
    Write-Info "Updating existing repository..."
    Set-Location $RepoDir
    git pull
} else {
    Write-Info "Cloning repository..."
    git clone https://github.com/meha1999/paqet-ui.git $RepoDir
    Set-Location $RepoDir
}
Write-Success "Repository ready at $RepoDir"

# Step 2: Check Go
$Go = Get-Command go -ErrorAction SilentlyContinue
if (-not $Go) {
    Write-Error "Go is required but not installed"
    Write-Host "Install from: https://golang.org/dl"
    exit 1
}
$GoVersion = go version
Write-Success "$GoVersion"

# Step 3: Check PostgreSQL / Docker
$HasPostgres = $null -ne (Get-Command psql -ErrorAction SilentlyContinue)
if (-not $HasPostgres) {
    Write-Warn "PostgreSQL not found. Using Docker PostgreSQL..."
    
    $HasDocker = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
    if (-not $HasDocker) {
        Write-Error "Docker is required for PostgreSQL"
        Write-Host "Install Docker from: https://docker.com"
        exit 1
    }
    
    Write-Info "Starting PostgreSQL container..."
    docker ps | Select-String "paqet-postgres" -ErrorAction SilentlyContinue | ForEach-Object { docker stop paqet-postgres }
    docker ps -a | Select-String "paqet-postgres" -ErrorAction SilentlyContinue | ForEach-Object { docker rm paqet-postgres }
    
    docker run -d `
        --name paqet-postgres `
        -e POSTGRES_USER=paqet `
        -e POSTGRES_PASSWORD=paqet `
        -e POSTGRES_DB=paqet_ui `
        -p 5432:5432 `
        postgres:15-alpine
    
    Write-Success "PostgreSQL container started"
    Start-Sleep -Seconds 3
} else {
    Write-Success "PostgreSQL found"
}

# Step 4: Setup database credentials
Write-Info "Configuring database connection..."
$env:DATABASE_USER = "paqet"
$env:DATABASE_PASSWORD = "paqet"
$env:DATABASE_HOST = "localhost"
$env:DATABASE_PORT = "5432"
$env:DATABASE_NAME = "paqet_ui"

# Step 5: Clean and build
Write-Info "Building application..."
Remove-Item -Path go.sum -Force -ErrorAction SilentlyContinue
go clean -modcache
go mod tidy
go build -o paqet-ui.exe

if (-not (Test-Path paqet-ui.exe)) {
    Write-Error "Build failed"
    exit 1
}
Write-Success "Build complete"

# Step 6: Create app directory
$AppDir = "$Home\AppData\Local\paqet-ui"
New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
Copy-Item -Path paqet-ui.exe -Destination $AppDir -Force
Write-Success "Binary copied to $AppDir"

# Step 7: Set up .env file
$EnvDir = "$Home\.paqet-ui"
New-Item -ItemType Directory -Path $EnvDir -Force | Out-Null
$EnvFile = "$EnvDir\.env"
@"
DATABASE_USER=paqet
DATABASE_PASSWORD=paqet
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=paqet_ui
"@ | Out-File -FilePath $EnvFile -Encoding UTF8
Write-Success "Environment configured at $EnvFile"

# Step 8: Run application
Write-Info "Starting Paqet UI..."
Write-Host ""
Write-Host "$($Colors.Green)═══════════════════════════════════════$($Colors.Reset)"
Write-Host "$($Colors.Green)  Paqet UI is Starting$($Colors.Reset)"
Write-Host "$($Colors.Green)═══════════════════════════════════════$($Colors.Reset)"
Write-Host ""
Write-Host "📍 URL: http://localhost:2053/panel"
Write-Host "👤 Default username: admin"
Write-Host "🔐 Default password: admin"
Write-Host ""
Write-Host "Database: PostgreSQL"
Write-Host "User: paqet"
Write-Host "Host: localhost:5432"
Write-Host ""
Write-Host "Press CTRL+C to stop"
Write-Host ""

Set-Location $RepoDir
& "$AppDir\paqet-ui.exe" -port 2053 -path /panel -username admin -password admin
