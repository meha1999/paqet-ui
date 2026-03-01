# Paqet UI Panel - Complete Web Management System

A modern, feature-rich web panel for managing and monitoring Paqet proxy configurations. Built with a Python (FastAPI) backend and a React + HeroUI frontend.

## 🚀 Quick Start

**One Command - Install, Enable Service, and Run**

### Linux (systemd)
```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.sh)
```
This script will:
- Clone the repository (or update if exists)
- Create a Python virtual environment
- Install dependencies (FastAPI, SQLAlchemy, uvicorn)
- Install frontend dependencies and build React app (HeroUI)
- Create and enable `paqet-ui` systemd service
- Start panel in background with auto-restart on failure
- Exit after setup (no foreground process)

### Windows PowerShell
```powershell
powershell -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.ps1'))"
```

### After Startup
1. Open **http://localhost:2053/panel** in your browser
2. Login with **admin / admin** (default credentials)
3. **Change your password** immediately (Settings → User Account)
4. Create your first proxy configuration

### Service Commands (Linux)
```bash
paqet-ui info
paqet-ui status
paqet-ui logs 200
paqet-ui logs-follow
paqet-ui restart
paqet-ui stop
paqet-ui start
paqet-ui uninstall
paqet-ui uninstall --purge
```

### Paqet Runtime Configuration

This panel controls a real Paqet process using:

```bash
paqet run -c <config-file>
```

If your Paqet binary is not in `PATH`, set:

```bash
export PAQET_BINARY=/full/path/to/paqet
```

Then use the dashboard buttons (`Start`, `Stop`, `Restart`) to manage the active configuration.

**For detailed installation instructions**, see [INSTALLATION.md](INSTALLATION.md)

---

## Features

### Dashboard
- **Real-time Statistics**: Monitor active configurations, connection counts, and traffic
- **Quick Controls**: Start, stop, and restart configurations directly from dashboard
- **System Information**: View panel version, uptime, and status
- **Recent Activity**: Track configuration changes and connection events

### Configuration Management
- **Create/Edit/Delete**: Full YAML-based configuration management
- **Syntax Validation**: Validate YAML before deployment
- **Test Deployment**: Test configurations before activating
- **Role Support**: Manage both client and server configurations
- **Active Config Indicator**: Visual indicator for currently active configuration

### Connection Monitoring
- **Live Connection Tracking**: Monitor all active and inactive connections
- **Traffic Statistics**: Real-time bytes in/out monitoring
- **Connection Status**: View status (running, stopped, error)
- **Auto-refresh**: Data updates automatically every 3-5 seconds

### Settings & Administration
- **User Management**: Default admin account (changeable)
- **Panel Configuration**: Customize port, base path, SSL settings
- **Logging**: Activity and error logging with file export
- **Backup & Restore**: Database backup and restore functionality

### Security Features
- **Session Authentication**: Secure login with session cookies
- **API Authorization**: Protected REST API endpoints
- **HTTPS Support**: Optional SSL/TLS encryption
- **CSRF Protection**: Built-in CSRF token validation

## Project Structure

```
paqet-ui/
├── app.py                           # FastAPI application entry point
├── models.py                        # SQLAlchemy ORM models
├── database.py                      # Database configuration
├── requirements.txt                 # Python dependencies
├── quick-setup.sh                   # One-liner installer (Linux/macOS)
├── quick-setup.ps1                  # One-liner installer (Windows)
├── web/
│   └── html/
│       ├── login.html               # Login page
│       ├── dashboard.html           # Main dashboard
│       ├── configurations.html      # Config management
│       ├── connections.html         # Connection viewer
│       ├── settings.html            # Settings page
│       ├── css/                     # Stylesheets
│       └── js/                      # JavaScript files with Axios API calls
├── config/                          # Legacy Go config (deprecated)
├── database/                        # Legacy Go database (deprecated)
└── README.md                        # This file
```

## Installation & Setup

### Prerequisites
- Python 3.8 or later
- Node.js 18+ and pnpm (for React frontend build)
- Git (for cloning the repository)
- systemd (for Linux service mode used by quick-setup.sh)
- `socat` (optional, required only for server upstream relay feature)
- Any modern web browser

### Quick Start

1. **Run the one-liner installer**:

   **Linux/macOS:**
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.sh)
   ```

   **Windows:**
   ```powershell
   powershell -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.ps1'))"
   ```

2. **Access the panel**:
   - Open http://localhost:2053/panel in your browser
   - Login: **admin** / **admin** (default credentials)
- Default credentials: `admin` / `admin`

### Command-line Options

```bash
go run main.go [options]

Options:
  -port int
        Web panel port (default: 2053)
  -path string
        Web panel base path (default: /panel)
  -username string
        Initial username (default: admin)
  -password string
        Initial password (default: admin)
  -reset-db
        Reset database on startup
```

## API Documentation

### Authentication
All API endpoints require authentication via session cookie.

**Login**:
```bash
POST /panel/login
Content-Type: application/x-www-form-urlencoded

username=admin&password=admin
```

### Configuration API

**Get all configurations**:
```bash
GET /panel/api/configs
```

**Create configuration**:
```bash
POST /panel/api/configs
Content-Type: application/json

{
  "name": "My Client",
  "role": "client",
  "config_yaml": "role: client\n..."
}
```

**Update configuration**:
```bash
PUT /panel/api/configs/:id
Content-Type: application/json

{
  "name": "Updated Name",
  "role": "client",
  "config_yaml": "..."
}
```

**Delete configuration**:
```bash
DELETE /panel/api/configs/:id
```

**Test configuration**:
```bash
POST /panel/api/configs/:id/test
```

**Start configuration**:
```bash
POST /panel/api/configs/:id/start
```

**Stop configuration**:
```bash
POST /panel/api/configs/:id/stop
```

### Connection API

**Get all connections**:
```bash
GET /panel/api/connections
```

**Get connection statistics**:
```bash
GET /panel/api/connections/stats?config_id=1
```

### Server API

**Get server status**:
```bash
GET /panel/api/status
```

**Get/Update settings**:
```bash
GET /panel/api/settings
PUT /panel/api/settings
```

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Configurations Table
```sql
CREATE TABLE configurations (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL,
  config_yaml TEXT,
  active BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  deleted_at TIMESTAMP
);
```

### Connections Table
```sql
CREATE TABLE connections (
  id SERIAL PRIMARY KEY,
  config_id INT NOT NULL,
  status VARCHAR(100) NOT NULL,
  bytes_in BIGINT,
  bytes_out BIGINT,
  last_activity_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  FOREIGN KEY (config_id) REFERENCES configurations(id)
);
```

### Logs Table
```sql
CREATE TABLE logs (
  id SERIAL PRIMARY KEY,
  level VARCHAR(50),
  message TEXT,
  source VARCHAR(255),
  created_at TIMESTAMP
);
```

### Settings Table
```sql
CREATE TABLE settings (
  id SERIAL PRIMARY KEY,
  key VARCHAR(255) UNIQUE,
  value TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

## Configuration File Format

When creating configurations through the panel, use standard Paqet YAML format:

### Client Configuration Example
```yaml
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:1080"
    username: ""
    password: ""

forward:
  - listen: "127.0.0.1:8080"
    target: "example.com:80"
    protocol: "tcp"

network:
  interface: "en0"
  ipv4:
    addr: "192.168.1.100:0"
    router_mac: "aa:bb:cc:dd:ee:ff"

server:
  addr: "10.0.0.100:9999"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    block: "aes"
    key: "your-secret-key-here"
```

### Server Configuration Example
```yaml
role: "server"

log:
  level: "info"

listen:
  addr: ":9999"

network:
  interface: "eth0"
  ipv4:
    addr: "10.0.0.100:9999"
    router_mac: "aa:bb:cc:dd:ee:ff"

transport:
  protocol: "kcp"
  kcp:
    block: "aes"
    key: "your-secret-key-here"
```

### Field Meanings
- `SOCKS5 Listen` (client): local SOCKS5 proxy address apps connect to.
- `Forward Listen` (client): local TCP address that accepts traffic for static forwarding.
- `Forward Target` (client): destination `host:port` for that client forward rule.
- `Server Listen Address` (server): Paqet server bind address. `:9999` means all interfaces on port `9999`.
- `Forward Listen (Relay)` (server, optional): local address where the relay listens.
- `Forward Target (Relay)` (server, optional): destination `host:port` where relay traffic is sent.

## Frontend Features

### Real-time Updates
- Auto-refresh dashboard every 5 seconds
- Live connection monitoring every 3 seconds
- WebSocket support for future real-time events (implemented)

### Responsive Design
- Mobile-friendly interface
- Collapsible sidebar for small screens
- Touch-optimized buttons and controls

### Dark/Light Modes
- Consistent color scheme (blue/purple gradient)
- High contrast for accessibility
- Smooth transitions and animations

### Data Visualization
- Statistics cards with live updates
- Connection status badges
- Traffic charts (future enhancement)
- Activity timeline (future enhancement)

## Development

### Local Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/meha1999/paqet-ui.git
   cd paqet-ui
   ```

2. **Create virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\Activate.ps1
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   pnpm --dir frontend install
   pnpm --dir frontend run build
   ```

4. **Run the application**:
   ```bash
   python app.py
   ```

### Adding New React Pages

1. Create a page component in `frontend/src/pages/`
2. Add route mapping in `frontend/src/App.jsx`
3. Rebuild frontend: `pnpm --dir frontend run build`

### Adding New API Endpoints

1. Add SQLAlchemy model in `models.py` if needed
2. Create database operation code using `get_db()` dependency
3. Add FastAPI route in `app.py` using `@app.get()`, `@app.post()`, etc.
4. Update frontend JavaScript to call new endpoint with Axios

### Environment Variables

Create `.env` file (optional):
```env
PORT=2053
DATABASE_URL=sqlite:///$HOME/.paqet-ui/paqet-ui.db
LOG_LEVEL=info
```

## Troubleshooting

### Port Already in Use
```bash
# Use different port - modify PORT in app.py or .env
PORT=3000 python app.py
```

### Virtual Environment Issues
```bash
# Recreate venv
rm -rf venv
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Cannot Connect to Panel
1. Ensure Python app is running (check console for "Uvicorn running on...")
2. Verify browser can access http://localhost:2053/panel
3. Check `.paqet-ui/` directory was created in home folder
4. Clear browser cache and cookies
4. Clear browser cache and cookies

### Configuration Won't Save
1. Verify YAML syntax is valid
2. Check database permissions
3. Review application logs for errors
4. Ensure required fields are filled

## Security Considerations

1. **Change default credentials immediately**
2. **Use HTTPS in production** (configure SSL certificates)
3. **Restrict admin access** (firewall rules, VPN)
4. **Regular backups** (export configuration)
5. **Monitor logs** (check for suspicious activity)
6. **Update regularly** (security patches)

## Future Enhancements

- [ ] WebSocket real-time updates
- [ ] Traffic statistics charts (Chart.js)
- [ ] Configuration templates
- [ ] Advanced log filtering
- [ ] User role management
- [ ] API key authentication
- [ ] Configuration versioning
- [ ] Automated backups
- [ ] Health checks and alerts
- [ ] Multi-language support (i18n)
- [ ] Dark mode toggle
- [ ] Configuration import/export

## License

MIT License - See LICENSE file for details

## Support & Contributing

For bugs, feature requests, or contributions, visit:
- GitHub Issues: [Report Issues]
- GitHub Discussions: [Ask Questions]
- Pull Requests: [Submit Changes]

## Credits

- **Paqet**: Raw packet transport proxy [GitHub](https://github.com/hanselime/paqet)
- **3x-UI**: Inspiration for panel design [GitHub](https://github.com/MHSanaei/3x-ui)
- **Gin Web Framework**: [GitHub](https://github.com/gin-gonic/gin)
- **GORM**: ORM library [GitHub](https://github.com/go-gorm/gorm)
- **Bootstrap**: UI framework [Website](https://getbootstrap.com)

## Version History

### v1.0.0 (Initial Release)
- Core dashboard functionality
- Configuration management (CRUD)
- Connection monitoring
- User authentication
- REST API endpoints
- Responsive web interface

---

**Last Updated**: 2024  
**Panel Version**: 1.0.0  
**Paqet Compatibility**: v1.0.0-alpha.19+
