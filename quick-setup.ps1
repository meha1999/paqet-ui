# Paqet UI Quick Setup - One Command Installation + Run (Windows)
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

# Step 2: Check Python
$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $Python) {
    Write-Error "Python is required but not installed"
    Write-Host "Install from: https://python.org"
    exit 1
}
$PythonVersion = python --version
Write-Success "$PythonVersion found"

# Step 3: Create virtual environment
Write-Info "Setting up Python environment..."
if (-not (Test-Path "venv")) {
    python -m venv venv
}
& "venv\Scripts\Activate.ps1"
Write-Success "Virtual environment activated"

# Step 4: Install dependencies
Write-Info "Installing Python packages..."
python -m pip install -q --upgrade pip
python -m pip install -q -r requirements.txt
Write-Success "Dependencies installed"

# Step 5: Create app data directory
$DataDir = "$Home\.paqet-ui"
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
Write-Success "Data directory ready at $DataDir"

# Step 6: Check Paqet binary
$PaqetBinary = if ($env:PAQET_BINARY) { $env:PAQET_BINARY } else { "paqet" }
$PaqetCmd = Get-Command $PaqetBinary -ErrorAction SilentlyContinue
if ($PaqetCmd) {
    Write-Success "Paqet binary found: $($PaqetCmd.Source)"
} else {
    Write-Warn "Paqet binary not found in PATH"
    Write-Warn "Install Paqet from https://github.com/hanselime/paqet"
    Write-Warn "Or set custom path: `$env:PAQET_BINARY='C:\path\to\paqet.exe'"
}

# Step 7: Run application
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
Write-Host "Backend: Python (FastAPI)"
Write-Host "Runtime: Paqet command = $PaqetBinary run -c <config>"
Write-Host "Database: SQLite (local file)"
Write-Host "Location: $DataDir\paqet-ui.db"
Write-Host ""
Write-Host "Press CTRL+C to stop"
Write-Host ""

python app.py
