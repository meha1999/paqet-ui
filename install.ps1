# Paqet UI Installation Script for Windows
# Quick installation for Windows systems
# Usage: powershell -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meha1999/paqet-ui/main/install.ps1'))"

param(
    [switch]$SkipService = $false
)

# Color codes
function Write-Info { Write-Host "[i] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[✓] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[⚠] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[✗] $args" -ForegroundColor Red }

# Check if running as admin (needed for service installation)
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Create directories
function Create-Directories {
    Write-Info "Creating directories..."
    
    $paqetDir = Join-Path $env:USERPROFILE ".paqet-ui"
    $backupDir = Join-Path $paqetDir "backups"
    
    New-Item -ItemType Directory -Force -Path $paqetDir | Out-Null
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    
    Write-Success "Directories created at $paqetDir"
    return $paqetDir
}

# Download or build application
function Install-Application {
    Write-Info "Installing Paqet UI..."
    
    $appDir = Join-Path $env:USERPROFILE ".local\bin"
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null
    
    $exePath = Join-Path $appDir "paqet-ui.exe"
    
    # Try to download pre-built binary from latest release
    try {
        Write-Info "Fetching latest release information..."
        $apiUrl = "https://api.github.com/repos/meha1999/paqet-ui/releases/latest"
        $headers = @{}
        
        # Add GitHub token if available for rate limiting
        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "token $env:GITHUB_TOKEN"
        }
        
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
        $downloadUrl = $release.assets | Where-Object { $_.name -like "*windows*" -or $_.name -like "*amd64*" } | Select-Object -ExpandProperty browser_download_url | Select-Object -First 1
        
        if ($downloadUrl) {
            Write-Info "Downloading binary..."
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath
            Write-Success "Binary downloaded to $exePath"
        } else {
            Write-Warn "No pre-built Windows binary found, building from source..."
            Install-FromSource -AppDir $appDir
        }
    } catch {
        Write-Warn "Failed to download binary: $_"
        Write-Warn "Building from source instead..."
        Install-FromSource -AppDir $appDir
    }
    
    # Add to PATH if not already
    if ($env:PATH -notlike "*$appDir*") {
        $env:PATH += ";$appDir"
        Write-Info "Added $appDir to PATH for this session"
    }
    
    return $exePath
}

# Build from source
function Install-FromSource {
    param([string]$AppDir)
    
    Write-Info "Building from source..."
    
    # Check for Go
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Error "Go is required to build from source. Please install Go 1.21+"
        Write-Info "Visit: https://golang.org/dl/"
        exit 1
    }
    
    # Create temp directory
    $tmpDir = New-Item -ItemType Directory -Path "$env:TEMP\paqet-ui-build-$(Get-Random)" | Select-Object -ExpandProperty FullName
    
    try {
        # Clone repository
        Write-Info "Cloning repository..."
        Push-Location $tmpDir
        git clone https://github.com/meha1999/paqet-ui.git
        cd paqet-ui
        
        # Build
        Write-Info "Building application..."
        go build -o paqet-ui.exe main.go
        
        # Install
        Move-Item -Path "paqet-ui.exe" -Destination (Join-Path $AppDir "paqet-ui.exe") -Force
        Write-Success "Built and installed to $(Join-Path $AppDir 'paqet-ui.exe')"
        
        Pop-Location
    } finally {
        # Cleanup
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}

# Setup Windows service
function Setup-Service {
    param([string]$ExePath)
    
    if ($SkipService) {
        Write-Warn "Service installation skipped"
        return
    }
    
    Write-Info "Setting up Windows service..."
    
    if (-not (Test-Admin)) {
        Write-Warn "Administrator privileges required for service installation"
        Write-Info "Please run this script as Administrator to install the service"
        return
    }
    
    $serviceName = "PaqetUI"
    
    # Check if service already exists
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        Write-Warn "Service already exists"
        return
    }
    
    # Create service
    try {
        New-Service -Name $serviceName `
                   -DisplayName "Paqet UI Web Panel" `
                   -BinaryPathName "$ExePath -port 2053 -path /panel" `
                   -StartupType Automatic `
                   -ErrorAction Stop | Out-Null
        
        Write-Success "Service created"
        
        # Start service
        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
        Write-Success "Service started"
        
    } catch {
        Write-Error "Failed to create service: $_"
    }
}

# Start application
function Start-Application {
    param([string]$ExePath)
    
    Write-Info "Starting Paqet UI..."
    
    # Check if service exists and is running
    $serviceName = "PaqetUI"
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        if ((Get-Service -Name $serviceName).Status -eq "Running") {
            Write-Success "Paqet UI is already running via service"
            return
        } else {
            Start-Service -Name $serviceName
            Write-Success "Service started"
            return
        }
    }
    
    # Start application directly
    Write-Info "Starting application directly..."
    $logPath = Join-Path $env:USERPROFILE ".paqet-ui\app.log"
    Start-Process -FilePath $ExePath -ArgumentList "-port 2053 -path /panel" -WindowStyle Hidden -RedirectStandardOutput $logPath
    Write-Success "Application started in background"
}

# Display access information
function Show-AccessInfo {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   Paqet UI - Quick Start Guide      ║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ Web Panel:   http://localhost:2053/panel" -ForegroundColor Green
    Write-Host "║ Default User: admin" -ForegroundColor Green
    Write-Host "║ Default Pass: admin" -ForegroundColor Green
    $paqetDir = Join-Path $env:USERPROFILE ".paqet-ui"
    Write-Host "║ Config Dir:   $paqetDir" -ForegroundColor Green
    Write-Host "║ Database:     $paqetDir\paqet-ui.db" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "⚠  IMPORTANT: Change the default password immediately!" -ForegroundColor Yellow
    Write-Host "   1. Open http://localhost:2053/panel in your browser" -ForegroundColor Yellow
    Write-Host "   2. Login with admin/admin" -ForegroundColor Yellow
    Write-Host "   3. Go to Settings → User Account" -ForegroundColor Yellow
    Write-Host "   4. Change your password" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Useful commands:" -ForegroundColor Cyan
    Write-Host "  View logs:      Get-Content (Join-Path `$PROFILE\.paqet-ui\app.log) -Wait" -ForegroundColor Cyan
    Write-Host "  Stop service:   Stop-Service -Name PaqetUI" -ForegroundColor Cyan
    Write-Host "  Start service:  Start-Service -Name PaqetUI" -ForegroundColor Cyan
    Write-Host "  Check status:   Get-Service -Name PaqetUI" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Documentation:" -ForegroundColor Cyan
    Write-Host "  Installation:    https://github.com/meha1999/paqet-ui/blob/main/INSTALLATION.md" -ForegroundColor Cyan
    Write-Host "  API Reference:   https://github.com/meha1999/paqet-ui/blob/main/API.md" -ForegroundColor Cyan
    Write-Host "  Troubleshooting: https://github.com/meha1999/paqet-ui/blob/main/TROUBLESHOOTING.md" -ForegroundColor Cyan
    Write-Host ""
}

# Main installation flow
function Main {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║  Paqet UI Installation Script       ║" -ForegroundColor Blue
    Write-Host "║           v1.0.0                    ║" -ForegroundColor Blue
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    
    Write-Success "Windows detected"
    
    $paqetDir = Create-Directories
    $exePath = Install-Application
    
    Setup-Service -ExePath $exePath
    Start-Application -ExePath $exePath
    
    Show-AccessInfo
}

# Run main
Main
