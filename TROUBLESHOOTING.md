# Paqet UI - Troubleshooting Guide

Solutions for common issues encountered while installing, running, or developing Paqet UI.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Database Issues](#database-issues)
3. [Runtime Issues](#runtime-issues)
4. [Authentication Issues](#authentication-issues)
5. [Network/Port Issues](#networkport-issues)
6. [Development Issues](#development-issues)
7. [Performance Issues](#performance-issues)
8. [Docker Issues](#docker-issues)
9. [Logs & Debugging](#logs--debugging)

---

## Installation Issues

### Issue: Go Version Not Compatible

**Symptoms**:
```
go: version "go1.20" does not match go 1.21 in go.mod
```

**Solution**:
```bash
# Update Go to 1.21+
# Download from https://golang.org/dl/

# Verify installation
go version  # Should output go version go1.21+ or higher

# If correct Go version is installed, clean cache
go clean -modcache
rm go.sum
go mod download
```

---

### Issue: Dependency Download Fails

**Symptoms**:
```
go get github.com/gin-gonic/gin: cannot find module providing package
```

**Solution**:
```bash
# Check internet connection
ping google.com

# Configure Go module proxy
export GOPROXY=https://proxy.golang.org

# Download dependencies again
go mod download
go mod tidy

# Or use direct mode (slower)
export GOPROXY=direct
go mod download
```

---

### Issue: Build Fails with CGO Error

**Symptoms**:
```
cgo: C compiler "gcc" not found: exec: "gcc": executable file not found
```

**Solution**:

**Linux (Ubuntu/Debian)**:
```bash
sudo apt-get update
sudo apt-get install build-essential
sudo apt-get install libsqlite3-dev
```

**macOS**:
```bash
xcode-select --install
brew install sqlite
```

**Windows**:
```powershell
# Install MinGW or use pre-built binary
# Or use: set CGO_ENABLED=0

# Disable CGO (works but slower)
$env:CGO_ENABLED="0"
go build -o paqet-ui.exe main.go
```

---

### Issue: Permission Denied (Linux/macOS)

**Symptoms**:
```
permission denied: ./paqet-ui
```

**Solution**:
```bash
# Make executable
chmod +x paqet-ui

# Or include in build
go build -o paqet-ui main.go && chmod +x paqet-ui

# Verify permissions
ls -l paqet-ui  # Should show -rwxr-xr-x
```

---

## Database Issues

### Issue: Database Locked

**Symptoms**:
```
database is locked
SQLITE_BUSY: database is locked
```

**Solution**:
```bash
# 1. Stop the application
killall paqet-ui
# or if running in background
pkill -f paqet-ui

# 2. Check for stray processes
ps aux | grep paqet-ui

# 3. Remove lock file if it exists
rm ~/.paqet-ui/paqet-ui.db-shm
rm ~/.paqet-ui/paqet-ui.db-wal

# 4. Restart application
./paqet-ui
```

---

### Issue: Database Corruption

**Symptoms**:
```
database disk image is malformed
SQLITE_CORRUPT: database disk image is malformed
```

**Solution**:
```bash
# 1. Backup corrupted database
cp ~/.paqet-ui/paqet-ui.db ~/.paqet-ui/paqet-ui.db.corrupted

# 2. Check database integrity
sqlite3 ~/.paqet-ui/paqet-ui.db "PRAGMA integrity_check;"

# 3. Attempt recovery
sqlite3 ~/.paqet-ui/paqet-ui.db ".recover" > recovered.sql

# 4. Delete corrupted database and let app recreate it
rm ~/.paqet-ui/paqet-ui.db

# 5. Start app with reset flag
./paqet-ui -reset-db

# 6. Restore data from backup (if available)
# Use Settings → Backup & Restore → Import
```

---

### Issue: Permissions ERROR: unable to write to database

**Symptoms**:
```
unable to open database file
SQLITE_READONLY: attempt to write a readonly database
```

**Solution**:

**Linux/macOS**:
```bash
# Check directory permissions
ls -ld ~/.paqet-ui/

# Fix permissions (user should own the directory)
mkdir -p ~/.paqet-ui
chmod 700 ~/.paqet-ui

# Or if running as service
sudo chown -R paqet-ui:paqet-ui /opt/paqet-ui
sudo chmod 755 /opt/paqet-ui
```

**Windows**:
```powershell
# Run PowerShell as Administrator
Start-Process powershell -Verb RunAs

# Grant permissions
icacls "C:\Users\Username\.paqet-ui" /grant "${env:USERNAME}:(F)"
```

---

### Issue: Cannot Find Database File

**Symptoms**:
```
database creation failed: open ~/.paqet-ui/paqet-ui.db: no such file or directory
```

**Solution**:
```bash
# 1. Verify database path
echo $HOME
ls -la ~/.paqet-ui/

# 2. Create directory if missing
mkdir -p ~/.paqet-ui

# 3. Run with explicit reset
./paqet-ui -reset-db

# 4. Verify creation
ls -l ~/.paqet-ui/paqet-ui.db  # Should show file with size > 0
```

---

## Runtime Issues

### Issue: Application Crashes on Startup

**Symptoms**:
```
panic: reflect.Set: value of type ... is not assignable to type ...
fatal error: all goroutines are asleep - deadlock!
```

**Solution**:
```bash
# 1. Check Go version again
go version

# 2. Clean and rebuild
go clean -cache -testcache
rm go.sum
go mod download
go mod verify

# 3. Complete rebuild
go build -o paqet-ui main.go

# 4. Run with verbose output
./paqet-ui -v 2>&1 | head -50
```

---

### Issue: Out of Memory (OOM)

**Symptoms**:
```
fatal error: runtime: out of memory
```

**Solution**:
```bash
# 1. Check system memory
free -h      # Linux
vm_stat      # macOS
Get-Process | Measure-Object -Property WorkingSet -Sum  # Windows

# 2. Check ulimits (Linux)
ulimit -a

# 3. Increase limits
ulimit -n 65535  # Max open files
ulimit -m 2097152  # Max memory (2GB)

# 4. For systemd service, add to [Service] section:
# MemoryLimit=1G
# LimitNOFILE=65535

# 5. Monitor memory usage
watch 'ps aux | grep paqet-ui | grep -v grep'
```

---

### Issue: Goroutine Leak (Memory Keeps Growing)

**Symptoms**:
- Memory usage increases over time
- Eventually runs out of memory
- Process becomes slower

**Solution**:
```bash
# 1. Enable profiling
# Add to config or env var: ENABLE_PROFILING=true

# 2. Analyze goroutines
go tool pprof http://localhost:6060/debug/pprof/goroutine

# 3. Look for:
# - Unclosed channels
# - Goroutines without exit conditions
# - Resource leaks in tight loops

# 4. Check logs for patterns
grep -i "goroutine\|leak\|close" ~/.paqet-ui/app.log

# 5. If identified
# - Fix in source code
# - Rebuild and test
# - Use pprof again to verify
```

---

## Authentication Issues

### Issue: Always Redirects to Login

**Symptoms**:
- Login works temporarily
- Gets redirected to login on every request
- Session lost immediately

**Solution**:
```bash
# 1. Check session settings
# Verify SESSION_TIMEOUT is set (should be > 0)
echo $SESSION_TIMEOUT  # Should show value like 86400

# 2. Clear cookies and retry
# In browser: F12 → Application → Cookies → Delete session_id

# 3. Check browser compatibility
# Ensure "HttpOnly" cookies are supported:
# - Chrome 55+
# - Firefox 52+
# - Safari 11+
# - Edge 15+

# 4. If running behind proxy, ensure:
# - proxy_set_header X-Forwarded-Proto $scheme;
# - proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
# - Session secure flag matches HTTPS usage
```

---

### Issue: Cannot Login - Invalid Credentials

**Symptoms**:
- Login always fails with "Invalid credentials"
- Default admin/admin doesn't work

**Solution**:
```bash
# 1. Reset database with default credentials
./paqet-ui -reset-db

# 2. Or set new credentials via CLI
./paqet-ui -username newadmin -password newpass -reset-db

# 3. Verify user was created
sqlite3 ~/.paqet-ui/paqet-ui.db \
  "SELECT id, username, created_at FROM users;"

# 4. If still fails, check password hashing
sqlite3 ~/.paqet-ui/paqet-ui.db \
  "SELECT id, username, LENGTH(password) FROM users;"
# Password should be 64 characters (SHA256 hex)

# 5. Clear browser cache and cookies
# CTRL+Shift+Delete in most browsers
# Or manually delete session_id cookie
```

---

### Issue: Lost Admin Password

**Symptoms**:
- Forgot admin password
- Cannot login to system

**Solution**:
```bash
# Direct database reset (all data lost)
rm ~/.paqet-ui/paqet-ui.db
./paqet-ui -reset-db

# Or reset and restore from backup
cp ~/.paqet-ui/paqet-ui.db.bak ~/.paqet-ui/paqet-ui.db
sqlite3 ~/.paqet-ui/paqet-ui.db \
  "DELETE FROM users; INSERT INTO users (username, password) VALUES ('admin', 'hash');"

# Better: if you have DB backup before password loss
./paqet-ui  # Start fresh
# Go to Settings → Backup & Restore
# Click "Import Database" and select backed-up file
```

---

## Network/Port Issues

### Issue: Port Already in Use

**Symptoms**:
```
listen tcp :2053: bind: address already in use
```

**Solution**:

**Linux/macOS**:
```bash
# Find process using port
lsof -i :2053

# Kill the process
kill -9 <PID>

# Or use different port
./paqet-ui -port 3000

# Verify port is free
netstat -tlnp | grep :2053  # Should show nothing
```

**Windows**:
```powershell
# Find process using port
netstat -ano | findstr :2053

# Kill process
taskkill /PID <PID> /F

# Or use different port
.\paqet-ui.exe -port 3000
```

---

### Issue: Cannot Access from Remote Host

**Symptoms**:
- Local access works: http://localhost:2053
- Remote access fails: http://192.168.1.100:2053

**Solution**:
```bash
# 1. Verify application is listening on all interfaces
netstat -tlnp | grep paqet-ui
# Should show 0.0.0.0:2053 (not 127.0.0.1:2053)

# 2. If showing 127.0.0.1, set PANEL_HOST=0.0.0.0
PANEL_HOST=0.0.0.0 ./paqet-ui

# 3. Check firewall
# Linux
sudo ufw allow 2053

# macOS
sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add ./paqet-ui

# Windows (PowerShell as Admin)
New-NetFirewallRule -DisplayName "Paqet UI" -Direction Inbound `
  -Protocol TCP -LocalPort 2053 -Action Allow

# 4. Check reverse proxy configuration (if using Nginx)
# Verify proxy_pass http://paqet-ui:2053;
```

---

### Issue: CORS Errors - Request Blocked

**Symptoms**:
```
Access to XMLHttpRequest at 'http://...' from origin 'http://...' 
has been blocked by CORS policy
```

**Solution**:
```bash
# 1. Verify CORS middleware is enabled
grep -r "CORSMiddleware" web/

# 2. Check if origin is whitelisted
# Edit web/middleware/middleware.go
# Add your domain to allowed origins

# 3. For development, temporarily allow all
# In middleware.go:
ctx.Writer.Header().Set("Access-Control-Allow-Origin", "*")
ctx.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
ctx.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

# 4. Rebuild and restart
go build -o paqet-ui main.go
./paqet-ui
```

---

## Development Issues

### Issue: Changes Not Reflected (Hot Reload Not Working)

**Symptoms**:
- Edit Go code
- Application doesn't restart
- Changes don't appear

**Solution**:
```bash
# 1. Install air for hot reload
go install github.com/cosmtrek/air@latest

# 2. Initialize air config
air init

# 3. Run with air instead of go run
air

# 4. If air not found
$GOPATH/bin/air
# or add $GOPATH/bin to system PATH

# 5. Alternatively, manual rebuild
go build -o paqet-ui main.go
./paqet-ui
```

---

### Issue: Import Errors in IDE

**Symptoms**:
- VSCode shows "package not found"
- GoLand shows unresolved imports
- Code compiles fine from terminal

**Solution**:
```bash
# 1. Ensure dependencies are downloaded
go mod download
go mod tidy

# 2. VSCode: Install Go extension
# Open Extensions (Ctrl+Shift+X)
# Search "Go" and install by Golang

# 3. Configure Go tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/go-delve/delve/cmd/dlv@latest

# 4. Restart IDE
# Close and reopen VSCode/GoLand

# 5. Clean IDE cache
# VSCode: Ctrl+Shift+P → Developer: Reload Window
# GoLand: File → Invalidate Caches → Restart
```

---

### Issue: Tests Fail Locally but Pass in CI

**Symptoms**:
- `go test ./...` fails on local machine
- Tests pass on GitHub Actions / CI
- Different test results on Windows vs Linux

**Solution**:
```bash
# 1. Run tests with exact CI flags
go test -v -race -timeout 30s ./...

# 2. Set same Go version as CI
go version  # Should match CI go.yml

# 3. Check for Go version-specific code
grep -r "build +go" .

# 4. Reset module cache
go clean -modcache
go mod download

# 5. Run tests in isolated environment
mkdir test-run && cd test-run
git clone . && go test ./...
cd .. && rm -rf test-run

# 6. Check for timing issues (flaky tests)
for i in {1..10}; do
    echo "Run $i"
    go test ./... || break
done
```

---

### Issue: Debugging Not Working

**Symptoms**:
- Breakpoints not hit
- Debugger starts but doesn't stop
- Variables show "<unavailable>"

**Solution**:
```bash
# 1. Install delve debugger
go install github.com/go-delve/delve/cmd/dlv@latest

# 2. Run with debugging
dlv debug main.go

# 3. Or configure VSCode launch.json
{
  "name": "Launch",
  "type": "go",
  "request": "launch",
  "mode": "debug",
  "program": "${fileDirname}",
  "args": ["-port", "2053"]
}

# 4. Check debugger settings
# VSCode → Settings → Search "debug" → Verify settings

# 5. If still not working, try headless debug
dlv debug main.go --headless --listen=127.0.0.1:38697 --api-version=2
# Then connect VSCode to the debugger session
```

---

## Performance Issues

### Issue: Slow API Response Times

**Symptoms**:
- API calls take > 1 second
- Dashboard loads slowly
- Database queries are slow

**Solution**:
```bash
# 1. Enable query logging
sqlite3 ~/.paqet-ui/paqet-ui.db ".log stdout"

# 2. Check for missing indexes
sqlite3 ~/.paqet-ui/paqet-ui.db \
  "EXPLAIN QUERY PLAN SELECT * FROM configurations WHERE name = 'test';"

# 3. Analyze database
sqlite3 ~/.paqet-ui/paqet-ui.db "ANALYZE;"

# 4. Check database file size
ls -lh ~/.paqet-ui/paqet-ui.db

# 5. If large, vacuum to reclaim space
sqlite3 ~/.paqet-ui/paqet-ui.db "VACUUM;"

# 6. Add indexes if missing
sqlite3 ~/.paqet-ui/paqet-ui.db \
  "CREATE INDEX IF NOT EXISTS idx_config_active ON configurations(active);"

# 7. Monitor system resources
top  # Linux/macOS
Get-Process  # Windows
```

---

## Docker Issues

### Issue: Cannot Access Container from Host

**Symptoms**:
```
curl: (7) Failed to connect to localhost port 2053
```

**Solution**:
```bash
# 1. Check if container is running
docker ps | grep paqet-ui

# 2. Check port mapping
docker port paqet-ui

# 3. If no mapping, run with port flag
docker run -d -p 2053:2053 paqet-ui:latest

# 4. Check container logs
docker logs paqet-ui

# 5. Exec into container
docker exec -it paqet-ui sh
# Then: curl http://localhost:2053/panel
```

---

### Issue: Docker Build Fails with Module Error

**Symptoms**:
```
go: go.mod file not found in current directory or any parent directory
```

**Solution**:
```bash
# 1. Verify go.mod exists
ls -la go.mod

# 2. Ensure Dockerfile COPY includes go.mod
# Should have:
# COPY go.mod go.sum ./

# 3. Check Dockerfile syntax
docker build --progress=plain .

# 4. If git is not initialized
git init
git add .
git commit -m "Initial commit"

# 5. Build with BuildKit
export DOCKER_BUILDKIT=1
docker build .
```

---

### Issue: Docker Container Runs but App Crashes

**Symptoms**:
```
docker run ... && docker logs paqet-ui shows error
```

**Solution**:
```bash
# 1. Check entrypoint
docker run paqet-ui --help

# 2. Run container interactively
docker run -it paqet-ui /bin/sh
# Then manually run: ./paqet-ui

# 3. Check file permissions
docker exec paqet-ui ls -l paqet-ui

# 4. Verify base image has necessary tools
docker run --rm paqet-ui sqlite3 --version

# 5. Check environment variables
docker run --rm paqet-ui env | grep -i paqet
```

---

## Logs & Debugging

### Enabling Debug Logging

```bash
# Set log level environment variable
export LOG_LEVEL=debug

# Or in .env file
LOG_LEVEL=debug

# Run application
./paqet-ui

# Redirect logs to file
./paqet-ui > app.log 2>&1 &

# View logs in real-time
tail -f app.log
tail -f ~/.paqet-ui/app.log
```

---

### Creating Debug Report

When reporting bugs, include:

```bash
#!/bin/bash
# Create diagnostic report

echo "=== System Info ===" > debug-report.txt
uname -a >> debug-report.txt
go version >> debug-report.txt

echo -e "\n=== File Permissions ===" >> debug-report.txt
ls -la ~/.paqet-ui/ >> debug-report.txt

echo -e "\n=== Database Info ===" >> debug-report.txt
sqlite3 ~/.paqet-ui/paqet-ui.db "PRAGMA integrity_check;" >> debug-report.txt
sqlite3 ~/.paqet-ui/paqet-ui.db ".tables" >> debug-report.txt

echo -e "\n=== Recent Logs ===" >> debug-report.txt
tail -100 ~/.paqet-ui/app.log >> debug-report.txt

cat debug-report.txt
```

---

### Common Log Patterns and Solutions

| Pattern | Meaning | Solution |
|---------|---------|----------|
| `connection refused` | Cannot reach service | Check port, firewall, service status |
| `permission denied` | Access issue | Check file/directory permissions |
| `context deadline exceeded` | Timeout | Increase timeout, check network |
| `EOF` | Connection closed abruptly | Check logs for crash, restart service |
| `panic: interface conversion` | Type mismatch | Potential memory corruption, restart |

---

## Getting Help

When troubleshooting fails:

1. **Check Logs**: `tail -f ~/.paqet-ui/app.log`
2. **GitHub Issues**: https://github.com/yourusername/paqet-ui/issues
3. **Documentation**: Review DEVELOPMENT.md and README.md
4. **Community**: Check Paqet project: https://github.com/hanselime/paqet

**Include when reporting issues**:
- `go version` output
- `uname -a` (system info)
- Exact error message
- Steps to reproduce
- Debug report (from script above)

---

**Last Updated**: 2024-01-16  
**Version**: 1.0.0  
**Maintained By**: Development Team
