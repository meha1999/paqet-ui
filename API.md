# Paqet UI - API Documentation

Complete REST API reference for Paqet UI web panel. All endpoints are prefixed with `/panel/api/`.

## Table of Contents

1. [Authentication](#authentication)
2. [Configuration Management](#configuration-management)
3. [Connection Monitoring](#connection-monitoring)
4. [Settings Management](#settings-management)
5. [Server Status](#server-status)
6. [Error Handling](#error-handling)
7. [Examples](#examples)

---

## Authentication

All API endpoints (except login) require a valid session cookie. After login, a `session_id` cookie is set and must be included in subsequent requests.

### Login

**Endpoint**: `POST /panel/login`

**Description**: Authenticate user and create session.

**Request Body**:
```json
{
  "username": "admin",
  "password": "admin"
}
```

**Response** (Success):
```http
HTTP/1.1 200 OK
Set-Cookie: session_id=abc123def456; Path=/; HttpOnly; Max-Age=86400

{
  "success": true,
  "message": "Login successful"
}
```

**Response** (Failure):
```http
HTTP/1.1 401 Unauthorized

{
  "success": false,
  "message": "Invalid credentials"
}
```

### Logout

**Endpoint**: `POST /panel/logout`

**Description**: Invalidate current session.

**Response**:
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## Configuration Management

### List All Configurations

**Endpoint**: `GET /panel/api/configs`

**Description**: Retrieve all configurations with metadata.

**Query Parameters**:
- `role` (optional): Filter by role ("client" or "server")
- `active` (optional): Filter by active status ("true" or "false")

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "my-client",
      "role": "client",
      "config_yaml": "...",
      "active": true,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    },
    {
      "id": 2,
      "name": "my-server",
      "role": "server",
      "config_yaml": "...",
      "active": false,
      "created_at": "2024-01-14T15:20:00Z",
      "updated_at": "2024-01-14T15:20:00Z"
    }
  ]
}
```

**Status Codes**:
- `200 OK`: Success
- `401 Unauthorized`: Not authenticated
- `500 Internal Server Error`: Server error

---

### Get Configuration by ID

**Endpoint**: `GET /panel/api/configs/:id`

**Description**: Retrieve specific configuration details.

**Path Parameters**:
- `id` (required): Configuration ID

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "my-client",
    "role": "client",
    "config_yaml": "server:\n  addr: 127.0.0.1:1080\n",
    "active": true,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

**Error Response**:
```json
{
  "success": false,
  "message": "Configuration not found"
}
```

---

### Create Configuration

**Endpoint**: `POST /panel/api/configs`

**Description**: Create new proxy configuration.

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "name": "new-config",
  "role": "client",
  "config_yaml": "server:\n  addr: proxy.example.com:8080\nnetwork:\n  interface: eth0\n"
}
```

**Response** (Success):
```http
HTTP/1.1 201 Created

{
  "success": true,
  "data": {
    "id": 3,
    "name": "new-config",
    "role": "client",
    "config_yaml": "...",
    "active": false,
    "created_at": "2024-01-16T09:00:00Z",
    "updated_at": "2024-01-16T09:00:00Z"
  }
}
```

**Validation Rules**:
- `name`: Required, max 255 characters, must be unique
- `role`: Required, must be "client" or "server"
- `config_yaml`: Required, must be valid YAML

**Error Response**:
```json
{
  "success": false,
  "message": "Configuration name already exists"
}
```

---

### Update Configuration

**Endpoint**: `PUT /panel/api/configs/:id`

**Description**: Update existing configuration.

**Path Parameters**:
- `id` (required): Configuration ID

**Request Body**:
```json
{
  "name": "updated-config",
  "role": "client",
  "config_yaml": "server:\n  addr: new-proxy.example.com:8080\n"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "updated-config",
    "role": "client",
    "config_yaml": "...",
    "active": false,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-16T09:15:00Z"
  }
}
```

---

### Delete Configuration

**Endpoint**: `DELETE /panel/api/configs/:id`

**Description**: Delete configuration (soft delete - preserves history).

**Path Parameters**:
- `id` (required): Configuration ID

**Response**:
```json
{
  "success": true,
  "message": "Configuration deleted successfully"
}
```

**Note**: Configurations are soft-deleted (marked with DeletedAt timestamp) to preserve audit trail.

---

### Test Configuration

**Endpoint**: `POST /panel/api/configs/:id/test`

**Description**: Validate configuration YAML syntax and semantic correctness.

**Path Parameters**:
- `id` (required): Configuration ID

**Response** (Valid):
```json
{
  "success": true,
  "data": {
    "valid": true,
    "message": "Configuration is valid"
  }
}
```

**Response** (Invalid):
```json
{
  "success": true,
  "data": {
    "valid": false,
    "message": "Missing required field: server.addr",
    "errors": [
      {
        "field": "server.addr",
        "error": "Required field missing"
      }
    ]
  }
}
```

---

### Start Configuration

**Endpoint**: `POST /panel/api/configs/:id/start`

**Description**: Activate configuration and start proxy service.

**Path Parameters**:
- `id` (required): Configuration ID

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "active": true,
    "message": "Configuration started successfully"
  }
}
```

**Side Effects**:
- Deactivates all other configurations
- Starts paqet process with configuration
- Sets `active=true` in database
- Creates connection tracking record

---

### Stop Configuration

**Endpoint**: `POST /panel/api/configs/:id/stop`

**Description**: Deactivate configuration and stop proxy service.

**Request Body** (optional):
```json
{
  "force": false,
  "timeout": 30
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "active": false,
    "message": "Configuration stopped successfully"
  }
}
```

**Parameters**:
- `force`: Force kill if normal shutdown fails (default: false)
- `timeout`: Seconds to wait for graceful shutdown (default: 30)

---

## Connection Monitoring

### List All Connections

**Endpoint**: `GET /panel/api/connections`

**Description**: Retrieve all active and historical connections.

**Query Parameters**:
- `config_id` (optional): Filter by configuration ID
- `status` (optional): Filter by status (running, stopped, error)
- `limit` (optional): Max results (default: 100)

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "config_id": 1,
      "status": "running",
      "bytes_in": 1024000,
      "bytes_out": 512000,
      "last_activity_at": "2024-01-16T12:00:00Z",
      "created_at": "2024-01-16T11:50:00Z"
    },
    {
      "id": 2,
      "config_id": 1,
      "status": "stopped",
      "bytes_in": 2048000,
      "bytes_out": 1024000,
      "last_activity_at": "2024-01-16T11:45:00Z",
      "created_at": "2024-01-16T10:00:00Z"
    }
  ]
}
```

---

### Get Connection Statistics

**Endpoint**: `GET /panel/api/connections/stats`

**Description**: Retrieve aggregated statistics for all or specific configuration connections.

**Query Parameters**:
- `config_id` (optional): Limit stats to specific configuration

**Response**:
```json
{
  "success": true,
  "data": {
    "total_connections": 150,
    "active_connections": 45,
    "stopped_connections": 105,
    "total_bytes_in": 52428800,
    "total_bytes_out": 26214400,
    "average_connection_duration": 3600000000000,
    "uptime_percentage": 98.5
  }
}
```

---

### Get Connection Details

**Endpoint**: `GET /panel/api/connections/:id`

**Description**: Retrieve detailed information about specific connection.

**Path Parameters**:
- `id` (required): Connection ID

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "config_id": 1,
    "status": "running",
    "bytes_in": 1024000,
    "bytes_out": 512000,
    "packets_in": 512,
    "packets_out": 256,
    "last_activity_at": "2024-01-16T12:00:00Z",
    "created_at": "2024-01-16T11:50:00Z",
    "duration_seconds": 600
  }
}
```

---

## Settings Management

### Get All Settings

**Endpoint**: `GET /panel/api/settings`

**Description**: Retrieve all panel settings and preferences.

**Response**:
```json
{
  "success": true,
  "data": {
    "panel_port": "2053",
    "panel_path": "/panel",
    "language": "en",
    "theme": "light",
    "session_timeout": "86400",
    "enable_https": "false",
    "enable_api_key": "false",
    "log_level": "info",
    "backup_enabled": "true"
  }
}
```

---

### Update Settings

**Endpoint**: `PUT /panel/api/settings`

**Description**: Update one or multiple panel settings.

**Request Body**:
```json
{
  "language": "zh",
  "theme": "dark",
  "log_level": "debug"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Settings updated successfully"
}
```

---

### Export Database

**Endpoint**: `GET /panel/api/settings/export`

**Description**: Export database backup as downloadable file.

**Response Headers**:
```
Content-Type: application/octet-stream
Content-Disposition: attachment; filename="paqet-ui-backup-20240116.db"
```

**Response Body**: Binary SQLite database file

---

### Import Database

**Endpoint**: `POST /panel/api/settings/import`

**Description**: Restore database from backup file (overwrites existing data).

**Request Headers**:
```
Content-Type: multipart/form-data
```

**Request Body**:
```
file: [binary SQLite database file]
```

**Response**:
```json
{
  "success": true,
  "message": "Database imported successfully. Application will restart."
}
```

**Warning**: This operation will:
1. Backup current database
2. Restore from imported file
3. Restart the application
4. Disconnect all sessions

---

## Server Status

### Get Server Status

**Endpoint**: `GET /panel/api/status`

**Description**: Retrieve overall server health and status information.

**Response**:
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "uptime_seconds": 86400,
    "version": "v1.0.0",
    "build_time": "2024-01-10T10:30:00Z",
    "git_commit": "abc123def",
    "database": {
      "status": "connected",
      "connections": 5,
      "size_bytes": 2097152
    },
    "memory": {
      "used_mb": 256,
      "total_mb": 512,
      "percentage": 50
    },
    "goroutines": 42,
    "cpu_usage_percent": 5.2
  }
}
```

---

## Error Handling

### Error Response Format

All error responses follow a consistent format:

```json
{
  "success": false,
  "message": "Error description",
  "code": "ERROR_CODE",
  "details": {
    "field": "Additional error context"
  }
}
```

### HTTP Status Codes

| Status | Meaning |
|--------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (not authenticated) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 409 | Conflict (duplicate resource) |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

### Common Error Codes

| Code | Meaning |
|------|---------|
| `INVALID_REQUEST` | Malformed request |
| `VALIDATION_ERROR` | Input validation failed |
| `NOT_FOUND` | Resource not found |
| `UNAUTHORIZED` | Authentication required |
| `FORBIDDEN` | No permission for resource |
| `DUPLICATE` | Resource already exists |
| `DATABASE_ERROR` | Database operation failed |
| `INTERNAL_ERROR` | Unexpected server error |

---

## Examples

### Complete Workflow Example

```bash
#!/bin/bash

# 1. Login
LOGIN=$(curl -s -c cookies.txt -X POST http://localhost:2053/panel/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}')

echo "Login: $LOGIN"

# 2. Get existing configurations
CONFIGS=$(curl -s -b cookies.txt http://localhost:2053/panel/api/configs)
echo "Configurations: $CONFIGS"

# 3. Create new configuration
NEW_CONFIG=$(curl -s -b cookies.txt -X POST http://localhost:2053/panel/api/configs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-proxy",
    "role": "client",
    "config_yaml": "server:\n  addr: 127.0.0.1:1080\n"
  }')

echo "New Config: $NEW_CONFIG"
CONFIG_ID=$(echo $NEW_CONFIG | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

# 4. Test configuration
TEST=$(curl -s -b cookies.txt -X POST \
  http://localhost:2053/panel/api/configs/$CONFIG_ID/test)
echo "Test: $TEST"

# 5. Start configuration
START=$(curl -s -b cookies.txt -X POST \
  http://localhost:2053/panel/api/configs/$CONFIG_ID/start)
echo "Start: $START"

# 6. Get statistics
STATS=$(curl -s -b cookies.txt \
  "http://localhost:2053/panel/api/connections/stats?config_id=$CONFIG_ID")
echo "Statistics: $STATS"

# 7. Stop configuration
STOP=$(curl -s -b cookies.txt -X POST \
  http://localhost:2053/panel/api/configs/$CONFIG_ID/stop)
echo "Stop: $STOP"

# 8. Delete configuration
DELETE=$(curl -s -b cookies.txt -X DELETE \
  http://localhost:2053/panel/api/configs/$CONFIG_ID)
echo "Delete: $DELETE"

# 9. Logout
LOGOUT=$(curl -s -b cookies.txt -X POST http://localhost:2053/panel/logout)
echo "Logout: $LOGOUT"
```

### JavaScript/Fetch Example

```javascript
// Setup
const baseUrl = 'http://localhost:2053/panel/api';

// Helper function for authenticated requests
async function apiRequest(method, endpoint, data = null) {
  const options = {
    method: method,
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include' // Include cookies
  };

  if (data) {
    options.body = JSON.stringify(data);
  }

  const response = await fetch(`${baseUrl}${endpoint}`, options);
  return await response.json();
}

// Examples
(async () => {
  // List configurations
  const configs = await apiRequest('GET', '/configs');
  console.log('Configurations:', configs);

  // Create configuration
  const newConfig = await apiRequest('POST', '/configs', {
    name: 'my-config',
    role: 'client',
    config_yaml: 'server:\n  addr: 127.0.0.1:1080\n'
  });
  console.log('Created:', newConfig);

  // Start configuration
  if (newConfig.success) {
    const started = await apiRequest('POST', 
      `/configs/${newConfig.data.id}/start`);
    console.log('Started:', started);
  }

  // Get statistics
  const stats = await apiRequest('GET', '/connections/stats');
  console.log('Statistics:', stats);
})();
```

---

**Last Updated**: 2024-01-16  
**Version**: 1.0.0  
**API Base URL**: `http://localhost:2053/panel`
