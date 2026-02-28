# Paqet UI Panel - Complete Web Management System

A modern, feature-rich web panel for managing and monitoring Paqet proxy configurations. Built with Go (Gin) backend and Vue.js/Bootstrap frontend.

## 🚀 Quick Start

**One Command - Build from Source + Run Immediately**

### Linux & macOS
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.sh)
```
This script will:
- Clone the repository (or update if exists)
- Install Go dependencies
- Start PostgreSQL via Docker (if not available)
- Build the application
- Launch the web panel at **http://localhost:2053/panel**

### Windows PowerShell
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/meha1999/paqet-ui/main/quick-setup.ps1'))
```

### After Startup
1. Open **http://localhost:2053/panel** in your browser
2. Login with **admin / admin** (default credentials)
3. **Change your password** immediately (Settings → User Account)
4. Create your first proxy configuration

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
├── main.go                          # Application entry point
├── go.mod                           # Go module definition
├── config/
│   └── config.go                    # Configuration management
├── database/
│   ├── db.go                        # Database initialization
│   ├── helper.go                    # Database utilities
│   └── model/
│       └── model.go                 # GORM data models
├── web/
│   ├── web.go                       # Web server setup
│   ├── controller/
│   │   ├── index.go                 # Login/Index controller
│   │   ├── panel.go                 # Panel pages controller
│   │   └── api.go                   # REST API controller
│   ├── service/
│   │   ├── auth.go                  # Authentication service
│   │   ├── config.go                # Configuration service
│   │   └── connection.go            # Connection tracking
│   ├── middleware/
│   │   └── middleware.go            # HTTP middleware
│   └── html/
│       ├── login.html               # Login page
│       ├── dashboard.html           # Main dashboard
│       ├── configurations.html      # Config management
│       └── connections.html         # Connection viewer
└── README.md                        # This file
```

## Installation & Setup

### Prerequisites
- Go 1.21 or later
- SQLite (bundled with Go)
- Any modern web browser

### Quick Start

1. **Clone/Setup the project**:
```bash
cd /path/to/paqet-ui
```

2. **Install dependencies**:
```bash
go mod download
```

3. **Run the panel**:
```bash
go run main.go -port 2053 -path /panel
```

4. **Access the panel**:
- Open http://localhost:2053/panel
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

### Adding New Pages

1. Create HTML template in `web/html/`
2. Add controller method in `web/controller/`
3. Add route in `web.go` setupRoutes function
4. Add navigation link in base layout

### Adding New API Endpoints

1. Add service method in `web/service/`
2. Add controller method in `web/controller/api.go`
3. Add route in `web.go` setupRoutes function
4. Update database models if needed

### Environment Variables

Create `.env` file:
```env
DB_PATH=/path/to/database.db
WEB_PORT=2053
WEB_PATH=/panel
LOG_LEVEL=info
```

## Troubleshooting

### Port Already in Use
```bash
# Use different port
go run main.go -port 3000
```

### Database Locked
```bash
# Reset database
go run main.go -reset-db
```

### Cannot Connect to Panel
1. Check if port is open: `netstat -tlnp | grep 2053`
2. Check panel logs for errors
3. Verify browser cookie support is enabled
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
