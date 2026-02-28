# Paqet UI - Installation & Setup Guide

A step-by-step guide to install and configure the Paqet UI web panel.

## Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04+, CentOS 8+), macOS 10.15+, or Windows 10+
- **Memory**: Minimum 512MB RAM
- **Disk Space**: 100MB for installation
- **Network**: Internet connection for initial setup

### Software Requirements
- **Go**: 1.21 or later ([Download](https://golang.org/dl/))
- **SQLite**: Usually pre-installed or bundled
- **Git**: For cloning repository (optional)

## Installation Steps

### Option 1: From Source (Recommended for Development)

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/paqet-ui.git
cd paqet-ui
```

#### 2. Install Go Dependencies
```bash
go mod download
go mod tidy
```

#### 3. Build the Application
```bash
# Linux/macOS
go build -o paqet-ui main.go

# Windows
go build -o paqet-ui.exe main.go
```

#### 4. Run the Application
```bash
# Default settings
./paqet-ui

# Custom settings
./paqet-ui -port 3000 -path "/myapp"
```

### Option 2: Using Docker (Production)

#### 1. Build Docker Image
```bash
docker build -t paqet-ui:latest .
```

#### 2. Run Container
```bash
docker run -d \
  --name paqet-ui \
  -p 2053:2053 \
  -v /data/paqet-ui:/home/paqet-ui/.paqet-ui \
  paqet-ui:latest
```

#### 3. Access Panel
- Open http://localhost:2053/panel
- Default: admin / admin

### Option 3: Binary Release (Simplest)

#### 1. Download Binary
- Visit [Releases](https://github.com/yourusername/paqet-ui/releases)
- Download binary for your OS

#### 2. Extract and Run
```bash
# Linux/macOS
chmod +x paqet-ui
./paqet-ui

# Windows
paqet-ui.exe
```

## Configuration

### Environment Variables

Create a `.env` file in the application directory:

```env
# Panel Settings
PANEL_PORT=2053
PANEL_PATH=/panel
PANEL_HOST=0.0.0.0

# Database
DB_PATH=~/.paqet-ui/paqet-ui.db

# Logging
LOG_LEVEL=info
LOG_FILE=~/.paqet-ui/app.log

# Security
SESSION_TIMEOUT=86400

# Features
ENABLE_HTTPS=false
SSL_CERT_FILE=
SSL_KEY_FILE=
```

### Command-line Flags

```bash
./paqet-ui \
  -port 2053 \
  -path /panel \
  -username admin \
  -password securepassword \
  -reset-db
```

**Available Flags**:
- `-port int` - Web panel port (default: 2053)
- `-path string` - Web panel base path (default: /panel)
- `-username string` - Initial admin username (default: admin)
- `-password string` - Initial admin password (default: admin)
- `-reset-db` - Reset database on startup (boolean flag)
- `-help` - Show help message

## Post-Installation

### 1. Change Default Password
1. Open http://localhost:2053/panel
2. Login with admin/admin
3. Go to Settings → User Account
4. Change your password immediately
5. Click "Change Password"

### 2. Configure Panel Settings
1. Go to Settings → Panel Settings
2. Adjust:
   - Base path (if needed)
   - Language preference
   - HTTPS settings (if using SSL)
3. Click "Save Settings"

### 3. Set Up First Configuration
1. Go to Configurations
2. Click "New Configuration"
3. Enter configuration details:
   - Name: Give it a descriptive name
   - Role: Select "client" or "server"
   - YAML: Paste your Paqet configuration
4. Click "Create"

### 4. Test Configuration
1. Click the test icon next to your configuration
2. System will validate YAML syntax
3. Check results in the notification popup

### 5. Start Configuration
1. Click the play icon to start the configuration
2. Monitor the dashboard for status updates

## Systemd Service (Linux)

### Create Service File

Create `/etc/systemd/system/paqet-ui.service`:

```ini
[Unit]
Description=Paqet UI Web Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=paqet-ui
Group=paqet-ui
WorkingDirectory=/opt/paqet-ui

ExecStart=/opt/paqet-ui/paqet-ui -port 2053 -path /panel
Restart=on-failure
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource Limits
LimitNOFILE=65535
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
```

### Install & Start Service

```bash
# Create user
sudo useradd -r -s /bin/false paqet-ui

# Copy application
sudo mkdir -p /opt/paqet-ui
sudo cp paqet-ui /opt/paqet-ui/
sudo chown -R paqet-ui:paqet-ui /opt/paqet-ui

# Install service
sudo systemctl daemon-reload
sudo systemctl enable paqet-ui
sudo systemctl start paqet-ui

# Check status
sudo systemctl status paqet-ui
```

## Nginx Reverse Proxy (Optional)

For production deployments, use Nginx as a reverse proxy:

### Nginx Configuration

Create `/etc/nginx/sites-available/paqet-ui`:

```nginx
upstream paqet_ui {
    server 127.0.0.1:2053;
}

server {
    listen 80;
    server_name paqet-ui.example.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name paqet-ui.example.com;

    # SSL Configuration
    ssl_certificate /etc/ssl/certs/paqet-ui.crt;
    ssl_certificate_key /etc/ssl/private/paqet-ui.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Logging
    access_log /var/log/nginx/paqet-ui-access.log;
    error_log /var/log/nginx/paqet-ui-error.log;

    location /panel {
        proxy_pass http://paqet_ui;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json;
}
```

### Enable Site

```bash
sudo ln -s /etc/nginx/sites-available/paqet-ui /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Database Backup & Recovery

### Automatic Backups

```bash
# Add to crontab
0 2 * * * cp ~/.paqet-ui/paqet-ui.db /backup/paqet-ui-$(date +\%Y\%m\%d).db
```

### Manual Backup

```bash
# Using Settings UI
1. Go to Settings → Backup & Restore
2. Click "Export Database"
3. Save the file to a safe location
```

Or via command line:

```bash
cp ~/.paqet-ui/paqet-ui.db ~/paqet-ui-backup-$(date +%s).db
```

### Restore from Backup

1. Go to Settings → Backup & Restore
2. Click "Choose backup file"
3. Select your backup
4. Click "Import Database"
5. Wait for confirmation message

## Troubleshooting Installation

### Issue: Port Already in Use
```bash
# Find what's using the port
lsof -i :2053

# Kill the process
kill -9 <PID>

# Or use different port
./paqet-ui -port 3000
```

### Issue: Permission Denied
```bash
# Make binary executable
chmod +x paqet-ui

# For systemd service
sudo chown -R paqet-ui:paqet-ui /opt/paqet-ui
sudo chmod 755 /opt/paqet-ui/paqet-ui
```

### Issue: Database Connection Error
```bash
# Reset database
./paqet-ui -reset-db

# Check database location
cat ~/.bashrc | grep PAQET
ls -la ~/.paqet-ui/
```

### Issue: Cannot Access Panel
```bash
# Check if service is running
systemctl status paqet-ui
ps aux | grep paqet-ui

# Check logs
journalctl -u paqet-ui -n 50

# Test port
curl http://localhost:2053/panel
```

### Issue: Slow Performance
```bash
# Check system resources
free -h
df -h
top

# Increase file descriptors
ulimit -n 65535

# Update in systemd service
LimitNOFILE=65535
```

## Security Hardening

### 1. Firewall Configuration
```bash
# UFW (Ubuntu)
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# firewalld (RHEL/CentOS)
sudo firewall-cmd --add-service=http
sudo firewall-cmd --add-service=https
sudo firewall-cmd --permanent
```

### 2. SSL/TLS Certificate
```bash
# With Let's Encrypt
sudo apt install certbot
certbot certonly --standalone -d paqet-ui.example.com

# Update Nginx
ssl_certificate /etc/letsencrypt/live/paqet-ui.example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/paqet-ui.example.com/privkey.pem;
```

### 3. Keep Updated
```bash
# Check for updates
git fetch origin
git log --oneline -5

# Update to latest
git pull origin main
go build -o paqet-ui main.go
systemctl restart paqet-ui
```

## Verification Checklist

After installation, verify:

- [ ] Application starts without errors
- [ ] Web panel accessible at http://localhost:2053/panel
- [ ] Can login with default credentials
- [ ] Can create a test configuration
- [ ] Dashboard displays correctly
- [ ] Settings can be changed
- [ ] Can export database backup
- [ ] Logs are being written
- [ ] Service auto-starts after reboot (if using systemd)
- [ ] HTTPS works (if configured)

## Next Steps

1. **Read the main README** for feature overview
2. **Configure your first proxy** using the configurations panel
3. **Review security settings** and change default password
4. **Set up automated backups** for your database
5. **Monitor logs** for any issues

---

**Need Help?**
- Check the troubleshooting section above
- Review application logs
- Visit GitHub Issues
- Check documentation at https://github.com/hanselime/paqet
