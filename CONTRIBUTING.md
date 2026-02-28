# Contributing to Paqet UI

Thank you for your interest in contributing to Paqet UI! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

We are committed to providing a welcoming and inclusive community. All contributors are expected to:

- Be respectful and constructive
- Welcome feedback and suggestions
- Focus on what is best for the community
- Show empathy towards other community members

## How to Contribute

### Reporting Bugs

Before creating a bug report, check if the issue already exists in the [Issues](https://github.com/yourusername/paqet-ui/issues) section.

**How to File a Good Bug Report**:

1. **Title**: Use a clear, descriptive title
   - ✅ Bad: "Dashboard doesn't work"
   - ✅ Good: "Dashboard fails to load when database connection times out"

2. **Description**: Include as much detail as possible
   ```
   ### Environment
   - OS: Ubuntu 22.04
   - Go Version: 1.21.5
   - Browser: Chrome 120
   
   ### Steps to Reproduce
   1. Start application
   2. Navigate to dashboard
   3. Wait 30 seconds
   
   ### Expected Behavior
   Dashboard should display statistics
   
   ### Actual Behavior
   Page shows error: "Connection timeout"
   
   ### Screenshots
   [Attach relevant screenshots]
   
   ### Logs
   [Include error logs from app.log]
   ```

3. **Additional Info**:
   - Exact version of Paqet UI
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots or logs

### Suggesting Enhancements

**How to Suggest a Good Enhancement**:

1. **Use a Clear, Descriptive Title**
   - ✅ Good: "Add dark mode toggle to settings"
   - ❌ Bad: "Improve UI"

2. **Provide Detailed Description**
   - Why would this enhancement be useful?
   - Who would benefit?
   - Examples of similar features elsewhere

3. **Example Usage**
   ```markdown
   ## Proposal
   Add dark mode toggle to settings panel
   
   ## Benefits
   - Reduces eye strain in low-light environments
   - Improves accessibility
   - Modern feature expected by users
   
   ## Example
   3x-ui has this feature - see: [screenshot]
   
   ## Implementation Complexity
   Low - CSS changes + localStorage toggle
   ```

### Pull Requests

**Before Creating a PR**:

1. Check if an issue exists or create one
2. Discuss significant changes in an issue first
3. Fork the repository
4. Create a feature branch
5. Make your changes
6. Write/update tests
7. Ensure code passes linting
8. Create the pull request

**PR Checklist**:

```markdown
## Description
[Explain your changes]

## Related Issue
Closes #[issue number]

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passed
- [ ] Manual testing completed
- [ ] No new warnings or errors

## Code Quality
- [ ] Follows project code style
- [ ] Comments added for complex logic
- [ ] No unused imports or variables
- [ ] Passes linting checks

## Documentation
- [ ] README.md updated if needed
- [ ] API.md updated for API changes
- [ ] CHANGELOG.md updated
- [ ] Code comments provided

## Screenshots (if UI change)
[Attach before/after screenshots]

## Breaking Changes
[Describe any breaking changes and migration path]
```

---

## Development Setup

### Prerequisites

- Go 1.21+
- SQLite3
- Make (optional, for convenience)
- Git

### Setup Instructions

```bash
# Clone repository
git clone https://github.com/yourusername/paqet-ui.git
cd paqet-ui

# Install dependencies
go mod download
go mod tidy

# Run application
go run main.go

# Or use make
make dev
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup instructions.

---

## Coding Standards

### Go Code Style

**File Organization**:
```go
package main

import (
    // stdlib
    "fmt"
    
    // external
    "github.com/gin-gonic/gin"
)

// Constants with explanatory comments
const (
    DefaultPort = 2053
)

// Types
type MyStruct struct {
    field string
}

// Methods
func (m *MyStruct) Do() error {
    // Implementation
}
```

**Naming Conventions**:
- Functions: `camelCase` for unexported, `PascalCase` for exported
- Variables: `camelCase` for local, `CONSTANT_CASE` for constants
- Interfaces: End with `er` (e.g., `Reader`, `Writer`)

**Error Handling**:
```go
// Always check errors
if err != nil {
    return nil, fmt.Errorf("context: %w", err)
}

// Use sentinel errors for specific conditions
if errors.Is(err, sql.ErrNoRows) {
    return nil, ErrNotFound
}
```

**Comments**:
```go
// Package auth provides authentication services
package auth

// Login authenticates a user with provided credentials
// Returns the authenticated user or an error if authentication fails
func Login(username, password string) (*User, error) {
    // Single-line comment for code explanation
    return user, nil
}
```

### JavaScript Code Style

```javascript
// Use camelCase for functions and variables
function loadConfigurations() {
    // Use const for immutable values
    const configs = [];
    
    // Use let for loop variables
    for (let i = 0; i < configs.length; i++) {
        // Use destructuring
        const { id, name } = configs[i];
    }
}

// Use arrow functions for callbacks
configurations.forEach((config) => {
    console.log(config.name);
});

// Use async/await for promises
async function fetchData() {
    try {
        const response = await axios.get('/api/configs');
        return response.data;
    } catch (error) {
        console.error('Error:', error);
    }
}
```

**HTML Templates**:
```html
<!-- Use semantic HTML5 -->
<main class="container">
    <!-- Use data attributes for JS selection -->
    <button id="save-btn" data-action="save">Save</button>
    
    <!-- Avoid inline styles -->
    <div class="card gradient-blue">
        <!-- Comments for complex sections -->
        <!-- Configuration form starts here -->
    </div>
</main>
```

### Database Changes

**Adding a Column**:
```go
// In database/model/model.go
type Configuration struct {
    // Existing fields
    ID    uint
    Name  string
    
    // New field with GORM tags
    Description string `gorm:"type:text;default:''"` // Added in v1.1.0
}

// Model already has auto-migration in database/db.go
// GORM will automatically add the column on startup
```

**Creating an Index**:
```go
// In database/model/model.go
type Connection struct {
    ConfigID  uint      // Add foreign key
    Status    string    `gorm:"index:idx_status"` // Add index
    CreatedAt time.Time `gorm:"index"`
}

// GORM processes the index tags automatically
```

---

## Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting (no logic change)
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Test additions/changes
- `chore`: Build/CI changes

**Examples**:
```
feat: add configuration validation

Implement YAML schema validation for configurations.
Supports both client and server roles with role-specific
required fields.

Fixes #123
```

```
fix: database locked when concurrent requests

Add connection pooling and transaction isolation to prevent
database lock issues under high concurrency.

Closes #456
```

---

## Testing

### Unit Tests

Create test files with `_test.go` suffix:

```go
// web/service/config_test.go
package service

import (
    "testing"
    "assert"
)

func TestCreateConfig(t *testing.T) {
    // Setup
    db := setupTestDB()
    service := NewConfigService(db)
    
    // Test execution
    config := &model.Configuration{
        Name: "test",
        Role: "client",
    }
    err := service.CreateConfig(config)
    
    // Assertions
    assert.NoError(t, err)
    assert.NotZero(t, config.ID)
}
```

**Run Tests**:
```bash
# All tests
go test ./...

# Specific package
go test ./web/service

# With coverage
go test -cover ./...

# With race detection
go test -race ./...
```

### Integration Tests

Test API endpoints:

```bash
# Start application
./paqet-ui &

# Test endpoint
curl -s http://localhost:2053/panel/api/configs | jq .

# Kill background process
jobs -l
kill %1
```

### Manual Testing

For UI changes, test in multiple browsers:
- Chrome/Chromium latest
- Firefox latest
- Safari (macOS)
- Edge (Windows)

---

## Documentation

### Updating Documentation

1. **README.md**: For major feature changes
2. **API.md**: For API endpoint changes
3. **DEVELOPMENT.md**: For setup or architecture changes
4. **TROUBLESHOOTING.md**: For new known issues or solutions
5. **CHANGELOG.md**: For all releases

### Code Comments

Add comments for:
- Exported functions (package-level doc comment)
- Complex algorithms
- Non-obvious implementation choices
- Bug workarounds with todo/fixme notes

```go
// ConfigService manages proxy configurations
type ConfigService struct { }

// SetActive deactivates all other configurations and activates the specified one.
// This ensures only one configuration runs at a time.
func (s *ConfigService) SetActive(id uint) error {
    // Implementation
}

// TODO: Optimize this query with better indexing (issue #789)
func (s *ConfigService) GetAllConfigs() []Configuration {
    // Implementation
}
```

---

## Code Review Process

### For Contributors

When your PR is submitted:

1. **Automated Checks**
   - GitHub Actions runs tests
   - Linting checks run
   - Coverage report generated

2. **Code Review**
   - Maintainers review the code
   - Comments and suggestions provided
   - Request changes if needed

3. **Addressing Feedback**
   - Respond to comments
   - Make requested changes
   - Push updates (don't close and reopen)

4. **Approval and Merge**
   - Maintainers approve the PR
   - CI must pass
   - PR is merged to main branch

### For Reviewers

Review checklist:
- [ ] Code follows style guidelines
- [ ] Comments are clear and helpful
- [ ] No unnecessary complexity
- [ ] Tests are adequate
- [ ] Documentation is updated
- [ ] No performance regressions
- [ ] Security issues are addressed

---

## Release Process

### Version Numbering

Use [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH` (e.g., 1.2.3)
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

### Release Steps

1. **Update CHANGELOG.md**
   ```markdown
   ## [1.1.0] - 2024-02-01
   
   ### Added
   - WebSocket real-time updates
   - Configuration templates
   
   ### Fixed
   - Database connection timeout
   ```

2. **Update Version in Code**
   - Update version constant in main.go (if present)
   - Update docker image tags
   - Update documentation versions

3. **Commit and Tag**
   ```bash
   git commit -m "chore: prepare release v1.1.0"
   git tag v1.1.0
   git push origin main --tags
   ```

4. **Create Release on GitHub**
   - Title: "v1.1.0 - Feature Release"
   - Description: Copy from CHANGELOG.md
   - Assets: Add built binaries

---

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **Discussions** (if enabled): General discussion
- **Wiki** (if enabled): Community documentation

### Helping Others

- Answer questions in issues
- Help test bug reports
- Improve documentation
- Share your experience and tips

---

## Recognition

Contributors are recognized in:

1. **CHANGELOG.md**: Every release credits contributors
2. **GitHub**: Automatically shown in contributors graph
3. **AUTHORS.md** (if created): Comprehensive contributor list

Example:
```markdown
## Contributors

- [@username](https://github.com/username) - Initial feature
- [@anotheruser](https://github.com/anotheruser) - Bug fixes
```

---

## Acknowledgments

- **Paqet Project**: For the proxy inspiration
- **3x-ui Project**: For the UI/UX patterns
- **Gin Framework Team**: For excellent HTTP framework
- **All Contributors**: For making this project better

---

## Questions?

- Check [DEVELOPMENT.md](DEVELOPMENT.md) for development questions
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Open an issue for clarification
- Join discussions about new features

---

## License

By contributing to Paqet UI, you agree that your contributions will be licensed under its MIT License.

---

**Thank you for contributing! 🎉**

We appreciate your time and effort to improve Paqet UI.

---

*Last Updated: 2024-01-16*  
*Version: 1.0.0*
