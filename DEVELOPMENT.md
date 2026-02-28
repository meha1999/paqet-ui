# Paqet UI - Development Guide

A comprehensive guide for developers contributing to or extending the Paqet UI project.

## Development Environment Setup

### Prerequisites

- **Go**: 1.21+ ([Official Downloads](https://golang.org/dl/))
- **Git**: 2.20+
- **VS Code** or preferred IDE
- **SQLite3**: For database inspection
- **curl** or **Postman**: For API testing

### Initial Setup

#### 1. Clone Repository
```bash
git clone https://github.com/yourusername/paqet-ui.git
cd paqet-ui
```

#### 2. Install Dependencies
```bash
go mod download
go mod tidy
```

#### 3. Run Application in Development Mode
```bash
# Set debug mode
export GO_ENV=development

# Run with hot reload (requires cosmtrek/air)
go install github.com/cosmtrek/air@latest
air

# Or direct run
go run main.go -port 2053 -path /panel -reset-db
```

#### 4. Access Development Panel
- Open http://localhost:2053/panel
- Login: admin/admin
- Database: Fresh SQLite at ~/.paqet-ui/paqet-ui.db

## Project Architecture

### Directory Structure

```
paqet-ui/
├── main.go                      # Entry point, CLI argument parsing
├── go.mod                       # Go module definition
├── README.md                    # User documentation
├── INSTALLATION.md              # Installation guide
├── DEVELOPMENT.md               # This file
│
├── config/
│   └── config.go               # Configuration management
│
├── database/
│   ├── db.go                   # GORM initialization, migrations
│   ├── helper.go               # Password hashing utilities
│   └── model/
│       └── model.go            # GORM data models (5 tables)
│
├── web/
│   ├── web.go                  # HTTP server setup, routing
│   ├── middleware/
│   │   └── middleware.go       # Auth, logging, error handling
│   ├── service/
│   │   ├── auth.go            # Authentication business logic
│   │   ├── config.go          # Configuration CRUD operations
│   │   └── connection.go      # Connection tracking
│   ├── controller/
│   │   ├── index.go           # Login/logout endpoints
│   │   ├── panel.go           # Page rendering controllers
│   │   └── api.go             # REST API endpoints (15+)
│   └── html/
│       ├── login.html         # Login page
│       ├── dashboard.html     # Main dashboard
│       ├── configurations.html # Config management UI
│       ├── connections.html   # Connection monitoring
│       └── settings.html      # Admin settings
```

### Architectural Patterns

#### 1. **Model-View-Controller (MVC)**
```
controller/      → Handles HTTP requests
    ↓
service/         → Business logic layer
    ↓
database/model/  → Data access & storage
```

#### 2. **Service Layer Design**
Each service handles one domain:
- `AuthService`: User authentication
- `ConfigService`: Configuration management
- `ConnectionService`: Connection tracking

#### 3. **Middleware Chain**
```
Request → Auth → Logging → CORS → JSON → Router → Handler → Response
```

#### 4. **API Response Format**
All endpoints return consistent JSON:
```json
{
  "success": true,
  "data": { /* entity data */ }
}
```

## Development Workflow

### Adding a New Feature

#### Step 1: Define the Model
Edit `database/model/model.go`:

```go
type Feature struct {
    ID        uint      `gorm:"primaryKey"`
    Name      string    `gorm:"index"`
    Status    string
    CreatedAt time.Time
    UpdatedAt time.Time
}

func (Feature) TableName() string {
    return "features"
}
```

#### Step 2: Create Database Migration
Database migrations run automatically via `AutoMigrate()` in `database/db.go`:

```go
func InitDB() error {
    // ... existing code
    db.AutoMigrate(&Feature{})  // Add this line
    // ...
}
```

#### Step 3: Create Service Layer
Create `web/service/feature.go`:

```go
package service

import (
    "paqet-ui/database/model"
    "gorm.io/gorm"
)

type FeatureService struct {
    db *gorm.DB
}

func NewFeatureService(db *gorm.DB) *FeatureService {
    return &FeatureService{db: db}
}

func (s *FeatureService) GetAll() ([]model.Feature, error) {
    var features []model.Feature
    if err := s.db.Find(&features).Error; err != nil {
        return nil, err
    }
    return features, nil
}

func (s *FeatureService) Create(feature *model.Feature) error {
    return s.db.Create(feature).Error
}

// ... other CRUD methods
```

#### Step 4: Create API Endpoints
Edit `web/controller/api.go`:

```go
type APIController struct {
    // ... existing fields
    featureService *service.FeatureService
}

func (c *APIController) GetFeatures(ctx *gin.Context) {
    features, err := c.featureService.GetAll()
    if err != nil {
        ctx.JSON(500, gin.H{"success": false, "message": err.Error()})
        return
    }
    ctx.JSON(200, gin.H{"success": true, "data": features})
}
```

#### Step 5: Register Routes
Edit `web/web.go` in `setupRoutes()`:

```go
func (s *Server) setupRoutes() {
    // ... existing routes
    api.GET("/features", s.apiController.GetFeatures)
}
```

#### Step 6: Create Frontend UI
Create `web/html/features.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Features</title>
    <!-- Include Bootstrap, jQuery, Axios -->
</head>
<body>
    <div class="container">
        <h1>Features</h1>
        <button onclick="loadFeatures()">Load Features</button>
        <div id="features-list"></div>
    </div>
    
    <script>
    function loadFeatures() {
        axios.get('/panel/api/features')
            .then(res => {
                // Render UI with res.data.data
            })
            .catch(err => console.error(err));
    }
    </script>
</body>
</html>
```

#### Step 7: Add Page Controller
Edit `web/controller/panel.go`:

```go
func (c *PanelController) Features(ctx *gin.Context) {
    ctx.HTML(200, "features.html", gin.H{})
}
```

Register route in `web/web.go`:
```go
panel.GET("/features", c.panelController.Features)
```

### Testing Your Changes

#### Unit Tests

Create `service/config_test.go`:

```go
package service

import (
    "testing"
    "gorm.io/gorm"
)

func TestCreateConfig(t *testing.T) {
    db := setupTestDB()
    service := NewConfigService(db)
    
    config := &model.Configuration{
        Name: "test",
        Role: "client",
    }
    
    err := service.CreateConfig(config)
    if err != nil {
        t.Errorf("Expected no error, got %v", err)
    }
}
```

Run tests:
```bash
go test ./...
```

#### API Testing with curl

```bash
# Create configuration
curl -X POST http://localhost:2053/panel/api/configs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-config",
    "role": "client",
    "config_yaml": "server:\n  addr: 127.0.0.1:1080"
  }'

# Get all configurations
curl http://localhost:2053/panel/api/configs

# Update configuration
curl -X PUT http://localhost:2053/panel/api/configs/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "updated-config"}'

# Delete configuration
curl -X DELETE http://localhost:2053/panel/api/configs/1
```

#### Testing with Postman

1. Import collection (create `.postman_collection.json`):
```json
{
  "info": { "name": "Paqet UI API" },
  "item": [
    {
      "name": "Get Configs",
      "request": {
        "method": "GET",
        "url": "http://localhost:2053/panel/api/configs"
      }
    }
  ]
}
```

2. Import into Postman and test endpoints

### Debugging

#### Enable Debug Logging

Set environment variable:
```bash
export LOG_LEVEL=debug
go run main.go
```

#### VS Code Debugging

Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Connect to Paqet",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}",
      "args": ["-port", "2053"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

Then press F5 to start debugging.

#### Common Issues

**Issue: Import not found**
```bash
go mod tidy
go mod download
```

**Issue: Database locked**
```bash
# Kill existing connections
pkill -f paqet-ui

# Reset database
rm ~/.paqet-ui/paqet-ui.db
```

**Issue: Port already in use**
```bash
# Find process
lsof -i :2053

# Kill process
kill -9 <PID>
```

## Code Style Guidelines

### Go Code Style

Follow standard Go conventions:

```go
// Use short variable names for local scope
for i := 0; i < len(items); i++ {
    // ...
}

// Use descriptive names for exported functions
func (s *FeatureService) GetAllFeatures() []Feature {
    // ...
}

// Error handling - always check
if err != nil {
    return nil, err
}

// Comments for exported types
// Feature represents a system feature
type Feature struct {
    // ...
}
```

### HTML/JavaScript Style

```html
<!-- Use ID for event handling -->
<button id="save-btn" onclick="saveConfig()">Save</button>

<!-- Use data-* attributes for data binding -->
<div data-config-id="1" class="config-item">
    <!-- ... -->
</div>

<!-- Function names in camelCase -->
<script>
function loadConfigurations() {
    axios.get('/panel/api/configs')
        .then(res => renderConfigurations(res.data.data))
        .catch(err => showError(err));
}
</script>
```

### Database Naming

- Tables: snake_case (connections, configurations)
- Fields: snake_case (created_at, is_active)
- Indexes: descriptive (idx_config_name, idx_user_username)

## Database Schema

### Creating Custom Indexes

```go
// In database/model/model.go
type Configuration struct {
    ID        uint   `gorm:"primaryKey"`
    Name      string `gorm:"index:idx_config_name"`  // Simple index
    Role      string
    ConfigYaml string
    ActiveAt  *time.Time `gorm:"index"`
}

// Or in custom migration
func init() {
    // Custom index in custom migration file
    // db.Model(&Configuration{}).CreateIndex("idx_config_role_name", "role", "name")
}
```

### Running Custom Migrations

Create `database/migrations/001_create_custom_index.sql`:

```sql
CREATE INDEX idx_connection_config_status 
ON connections(config_id, status);
```

Run manually:
```bash
sqlite3 ~/.paqet-ui/paqet-ui.db < database/migrations/001_create_custom_index.sql
```

## API Documentation

### Adding New Endpoints

1. **Define in service layer**
```go
func (s *ConfigService) SearchConfigs(role string) ([]Configuration, error) {
    var configs []Configuration
    s.db.Where("role = ?", role).Find(&configs)
    return configs, nil
}
```

2. **Create controller method**
```go
func (c *APIController) SearchConfigs(ctx *gin.Context) {
    role := ctx.Query("role")
    configs, err := c.configService.SearchConfigs(role)
    // ... error handling ...
    ctx.JSON(200, gin.H{"success": true, "data": configs})
}
```

3. **Register route**
```go
api.GET("/configs/search", c.SearchConfigs)
```

4. **Document in README**
```markdown
### Search Configurations
GET /api/configs/search?role=client

Response:
200 OK
{
  "success": true,
  "data": [...]
}
```

## Frontend Components

### Using Bootstrap 4 Grid

```html
<div class="container">
    <div class="row">
        <div class="col-md-8">Main content (8/12 on desktop)</div>
        <div class="col-md-4">Sidebar (4/12 on desktop)</div>
    </div>
</div>
```

### Using Modals

```html
<div class="modal fade" id="configModal" tabindex="-1">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Edit Configuration</h5>
        <button type="button" class="close" data-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <form id="configForm">
          <input type="text" id="configName" class="form-control">
        </form>
      </div>
      <div class="modal-footer">
        <button onclick="saveConfig()">Save</button>
      </div>
    </div>
  </div>
</div>

<script>
function showConfigModal(id) {
    $('#configModal').modal('show');
}
</script>
```

### Auto-refresh with Axios

```javascript
// Refresh every 5 seconds
setInterval(function() {
    axios.get('/panel/api/configs')
        .then(res => {
            updateUI(res.data.data);
        })
        .catch(err => console.error(err));
}, 5000);
```

## Security Considerations

### Input Validation

```go
// Always validate user input
func (s *ConfigService) CreateConfig(config *Configuration) error {
    if config.Name == "" {
        return fmt.Errorf("name cannot be empty")
    }
    if config.Role != "client" && config.Role != "server" {
        return fmt.Errorf("invalid role")
    }
    // ... create config
}
```

### SQL Injection Prevention

Use parameterized queries (GORM does this automatically):

```go
// Safe - GORM uses parameterized queries
db.Where("name = ?", userInput).Find(&configs)

// Never concat user input
// db.Where("name = '" + userInput + "'")  // WRONG!
```

### XSS Prevention

Always escape user data in HTML:

```html
<!-- Wrong -->
<div id="output">{{userInput}}</div>

<!-- Correct (Go templates auto-escape) -->
<div id="output">{{.UserInput}}</div>

<!-- Or in JavaScript -->
<div id="output"></div>
<script>
document.getElementById('output').textContent = userInput; // Safe
</script>
```

### CSRF Protection

Currently uses session cookies. To enhance:

```go
// Add CSRF token middleware
func CSRFMiddleware() gin.HandlerFunc {
    return func(ctx *gin.Context) {
        token := generateCSRFToken()
        ctx.Set("csrf_token", token)
        ctx.Next()
    }
}
```

## Performance Optimization

### Database Query Optimization

```go
// Use indexes
db.Model(&Connection{}).
    Where("config_id = ?", configID).
    Index("idx_connection_config_status").
    Find(&connections)

// Limit query results
db.Limit(100).Find(&connections)

// Batch operations
db.CreateInBatches(connections, 100)
```

### Frontend Performance

```javascript
// Debounce search input
function debounce(func, wait) {
    let timeout;
    return function(...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => func(...args), wait);
    };
}

const debouncedSearch = debounce(searchConfigs, 500);
```

## Contributing

### Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m "Add amazing feature"`
4. **Push** to branch: `git push origin feature/amazing-feature`
5. **Create** Pull Request with description

### Commit Message Guidelines

```
[Type] Brief description (50 chars max)

Detailed explanation (72 char wrap)
- Bullet point 1
- Bullet point 2

Fixes #123
```

Types: feat, fix, docs, style, refactor, perf, test

### Code Review Checklist

- [ ] Code follows style guidelines
- [ ] No hardcoded values
- [ ] Proper error handling
- [ ] Tests included
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## Deployment

### Building for Production

```bash
# Build for Linux
GOOS=linux GOARCH=amd64 go build -o paqet-ui

# Build for macOS
GOOS=darwin GOARCH=amd64 go build -o paqet-ui-mac

# Build for Windows
GOOS=windows GOARCH=amd64 go build -o paqet-ui.exe
```

### Creating Release

```bash
# Tag version
git tag v1.1.0

# Push tag
git push origin v1.1.0

# GitHub creates release automatically (with Actions)
```

## Useful Resources

- [Go Documentation](https://golang.org/doc/)
- [Gin Web Framework](https://gin-gonic.com/)
- [GORM Guide](https://gorm.io/)
- [Bootstrap 4 Docs](https://getbootstrap.com/docs/4.6/)
- [Paqet Documentation](https://github.com/hanselime/paqet)

## Troubleshooting Development

### Hot reload not working
```bash
go install github.com/cosmtrek/air@latest
air init  # Create .air.toml
air
```

### Module caching issues
```bash
go clean -modcache
go mod download
go mod tidy
```

### Database corruption
```bash
# Backup and reset
cp ~/.paqet-ui/paqet-ui.db ~/.paqet-ui/paqet-ui.db.bak
rm ~/.paqet-ui/paqet-ui.db
./paqet-ui -reset-db
```

---

Happy coding! 🚀

For questions, open an issue on GitHub or check the main README.md.
