# Multi-PocketBase Lab Server on Fly.io with Caddy

This guide shows you how to create a single server that can host multiple PocketBase SaaS applications dynamically, using Fly.io for hosting and Caddy for reverse proxy and SSL termination.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites & Setup](#prerequisites--setup) 
3. [Lab Server Implementation](#lab-server-implementation)
4. [Deployment Process](#deployment-process)
5. [App Management System](#app-management-system)
6. [Caddy Configuration](#caddy-configuration)
7. [Monitoring & Debugging](#monitoring--debugging)
8. [Production Considerations](#production-considerations)

## Architecture Overview

### High-Level Architecture

```
Internet → Fly.io Load Balancer → Caddy Reverse Proxy → PocketBase Apps
                                       ↓
Domain: lab.yourdomain.com
├── app1.lab.yourdomain.com → PocketBase:8091 (Volume: app1_data)
├── app2.lab.yourdomain.com → PocketBase:8092 (Volume: app2_data)  
└── app3.lab.yourdomain.com → PocketBase:8093 (Volume: app3_data)
```

### Component Responsibilities

**Caddy (Port 8080)**
- SSL termination for all subdomains
- Reverse proxy routing based on subdomain
- Automatic HTTPS certificate management
- Configuration reloading without downtime

**Lab Manager API (Port 9000)**
- REST API for deploying/removing apps
- Git repository cloning and building
- Port allocation management
- Caddy configuration updates
- Process lifecycle management

**PocketBase Apps (Ports 8091+)**
- Individual SaaS applications
- Isolated data storage per app
- Independent process management
- Health monitoring endpoints

**Process Supervisor**
- Ensures all services stay running
- Automatic restart on failure
- Graceful shutdown handling
- Log aggregation

### Data Flow

1. **App Deployment**: `POST /api/deploy` → Clone repo → Build → Allocate port → Update Caddy → Start process
2. **Request Routing**: `app1.lab.domain.com` → Caddy → `localhost:8091` → PocketBase App 1
3. **App Removal**: `DELETE /api/apps/app1` → Stop process → Cleanup data → Release port → Update Caddy

## Prerequisites & Setup

### Required Accounts & Tools

1. **Fly.io Account**
   ```bash
   # Install flyctl
   curl -L https://fly.io/install.sh | sh
   
   # Login to Fly.io
   fly auth login
   ```

2. **Domain Setup**
   - Purchase a domain (e.g., `yourdomain.com`)
   - Add domain to Fly.io: `fly domains add yourdomain.com`
   - Set up DNS wildcard: `*.lab.yourdomain.com CNAME your-app.fly.dev`

3. **Development Tools**
   ```bash
   # Required on your local machine
   git
   docker
   go (1.21+)
   node (18+)
   ```

### DNS Configuration

```
# DNS Records for yourdomain.com
Type    Name                Value
CNAME   *.lab              your-lab-server.fly.dev
CNAME   lab                your-lab-server.fly.dev
```

### Environment Variables

```bash
# Set these in your local environment
export DOMAIN_NAME="lab.yourdomain.com"
export FLY_APP_NAME="your-lab-server"
export GITHUB_TOKEN="your_github_token" # For private repos
```

## Lab Server Implementation

### Project Structure

```
lab-server/
├── Dockerfile
├── fly.toml
├── docker-compose.yml         # For local development
├── scripts/
│   ├── start.sh              # Main startup script
│   ├── deploy-app.sh         # App deployment script
│   └── cleanup-app.sh        # App removal script
├── caddy/
│   ├── Caddyfile.template    # Template for dynamic config
│   └── reload-caddy.sh       # Configuration reload script
├── lab-manager/
│   ├── main.go               # API server
│   ├── handlers.go           # HTTP handlers
│   ├── app_manager.go        # App lifecycle management
│   ├── port_manager.go       # Port allocation
│   └── config.go             # Configuration management
├── supervisor/
│   ├── supervisord.conf      # Process management config
│   └── programs/             # Individual app configs
└── data/
    ├── apps.json             # App registry
    ├── ports.json            # Port allocation
    └── caddy/               # Caddy config storage
```

### Dockerfile

```dockerfile
# Build lab manager
FROM golang:1.21-alpine AS builder-go
WORKDIR /app
COPY lab-manager/ .
RUN go mod download
RUN CGO_ENABLED=0 go build -o lab-manager

# Final image
FROM alpine:latest
WORKDIR /app

# Install dependencies
RUN apk add --no-cache \
    caddy \
    supervisor \
    git \
    curl \
    bash \
    jq \
    procps

# Create necessary directories
RUN mkdir -p \
    /app/data/apps \
    /app/data/caddy \
    /app/data/logs \
    /app/supervisor/programs \
    /var/log/supervisor

# Copy application files
COPY --from=builder-go /app/lab-manager /app/lab-manager
COPY scripts/ /app/scripts/
COPY caddy/ /app/caddy/
COPY supervisor/ /app/supervisor/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh
RUN chmod +x /app/lab-manager

# Create startup script
COPY <<'EOF' /app/start.sh
#!/bin/bash
set -e

echo "Starting Lab Server..."

# Initialize configuration files if they don't exist
if [ ! -f /app/data/apps.json ]; then
    echo '{"apps": {}}' > /app/data/apps.json
fi

if [ ! -f /app/data/ports.json ]; then
    echo '{"allocated": {}, "next_port": 8091}' > /app/data/ports.json
fi

# Generate initial Caddyfile
/app/scripts/generate-caddyfile.sh

# Start supervisor
exec supervisord -c /app/supervisor/supervisord.conf
EOF

RUN chmod +x /app/start.sh

EXPOSE 8080 9000

CMD ["/app/start.sh"]
```

### fly.toml

```toml
app = "your-lab-server"
primary_region = "ord"

[build]

[env]
  CADDY_PORT = "8080"
  LAB_MANAGER_PORT = "9000"
  DOMAIN_NAME = "lab.yourdomain.com"
  DATA_DIR = "/app/data"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "off"
  auto_start_machines = true
  min_machines_running = 1

  [http_service.checks]
    interval = "30s"
    timeout = "10s"
    method = "GET"
    path = "/health"

[[services]]
  internal_port = 9000
  protocol = "tcp"

  [[services.ports]]
    port = 9000

[[vm]]
  memory = "2gb"
  cpu_kind = "shared"
  cpus = 2

[[mounts]]
  source = "lab_data"
  destination = "/app/data"
  initial_size = "50gb"

[deploy]
  strategy = "immediate"
```

### Supervisor Configuration

```ini
; supervisor/supervisord.conf
[supervisord]
nodaemon=true
user=root
logfile=/app/data/logs/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/app/data/logs

[unix_http_server]
file=/tmp/supervisor.sock

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:caddy]
command=caddy run --config /app/data/caddy/Caddyfile
directory=/app
autostart=true
autorestart=true
stdout_logfile=/app/data/logs/caddy.log
stderr_logfile=/app/data/logs/caddy.error.log

[program:lab-manager]
command=/app/lab-manager
directory=/app
autostart=true
autorestart=true
stdout_logfile=/app/data/logs/lab-manager.log
stderr_logfile=/app/data/logs/lab-manager.error.log

[include]
files = /app/supervisor/programs/*.conf
```

### Lab Manager API (Go)

```go
// lab-manager/main.go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/gorilla/mux"
)

type Config struct {
    Port       string
    DataDir    string
    DomainName string
}

type AppRegistry struct {
    Apps map[string]*AppInfo `json:"apps"`
}

type AppInfo struct {
    Name       string    `json:"name"`
    Repository string    `json:"repository"`
    Port       int       `json:"port"`
    Status     string    `json:"status"`
    CreatedAt  time.Time `json:"created_at"`
    LastDeploy time.Time `json:"last_deploy"`
    Subdomain  string    `json:"subdomain"`
}

type PortManager struct {
    Allocated map[string]int `json:"allocated"`
    NextPort  int            `json:"next_port"`
}

func main() {
    config := &Config{
        Port:       getEnv("LAB_MANAGER_PORT", "9000"),
        DataDir:    getEnv("DATA_DIR", "/app/data"),
        DomainName: getEnv("DOMAIN_NAME", "lab.localhost"),
    }

    r := mux.NewRouter()
    
    // API routes
    r.HandleFunc("/health", healthHandler).Methods("GET")
    r.HandleFunc("/api/apps", listAppsHandler(config)).Methods("GET")
    r.HandleFunc("/api/deploy", deployAppHandler(config)).Methods("POST")
    r.HandleFunc("/api/apps/{name}", getAppHandler(config)).Methods("GET")
    r.HandleFunc("/api/apps/{name}", removeAppHandler(config)).Methods("DELETE")
    r.HandleFunc("/api/apps/{name}/restart", restartAppHandler(config)).Methods("POST")
    r.HandleFunc("/api/apps/{name}/logs", getLogsHandler(config)).Methods("GET")

    log.Printf("Lab Manager starting on port %s", config.Port)
    log.Fatal(http.ListenAndServe(":"+config.Port, r))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

// Additional handlers would be implemented here...
```

```go
// lab-manager/handlers.go
package main

import (
    "encoding/json"
    "fmt"
    "net/http"
    "os/exec"
    "path/filepath"
    "strings"
    "time"

    "github.com/gorilla/mux"
)

type DeployRequest struct {
    Repository string `json:"repository"`
    Subdomain  string `json:"subdomain"`
    Branch     string `json:"branch,omitempty"`
}

func deployAppHandler(config *Config) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        var req DeployRequest
        if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
            http.Error(w, "Invalid JSON", http.StatusBadRequest)
            return
        }

        // Validate subdomain
        if !isValidSubdomain(req.Subdomain) {
            http.Error(w, "Invalid subdomain", http.StatusBadRequest)
            return
        }

        // Check if app already exists
        registry, err := loadAppRegistry(config)
        if err != nil {
            http.Error(w, "Failed to load app registry", http.StatusInternalServerError)
            return
        }

        if _, exists := registry.Apps[req.Subdomain]; exists {
            http.Error(w, "App already exists", http.StatusConflict)
            return
        }

        // Allocate port
        portManager, err := loadPortManager(config)
        if err != nil {
            http.Error(w, "Failed to load port manager", http.StatusInternalServerError)
            return
        }

        port := portManager.NextPort
        portManager.Allocated[req.Subdomain] = port
        portManager.NextPort++

        if err := savePortManager(config, portManager); err != nil {
            http.Error(w, "Failed to save port allocation", http.StatusInternalServerError)
            return
        }

        // Create app info
        app := &AppInfo{
            Name:       req.Subdomain,
            Repository: req.Repository,
            Port:       port,
            Status:     "deploying",
            CreatedAt:  time.Now(),
            LastDeploy: time.Now(),
            Subdomain:  req.Subdomain,
        }

        registry.Apps[req.Subdomain] = app
        if err := saveAppRegistry(config, registry); err != nil {
            http.Error(w, "Failed to save app registry", http.StatusInternalServerError)
            return
        }

        // Deploy app asynchronously
        go func() {
            deployApp(config, app, req.Branch)
        }()

        w.WriteHeader(http.StatusAccepted)
        json.NewEncoder(w).Encode(app)
    }
}

func deployApp(config *Config, app *AppInfo, branch string) {
    // Implementation of app deployment logic
    appDir := filepath.Join(config.DataDir, "apps", app.Name)
    
    // Clone repository
    if err := cloneRepository(app.Repository, appDir, branch); err != nil {
        app.Status = "failed"
        updateAppStatus(config, app)
        return
    }

    // Build app
    if err := buildApp(appDir, app.Name); err != nil {
        app.Status = "failed"
        updateAppStatus(config, app)
        return
    }

    // Create supervisor config
    if err := createSupervisorConfig(config, app); err != nil {
        app.Status = "failed"
        updateAppStatus(config, app)
        return
    }

    // Update Caddy configuration
    if err := updateCaddyConfig(config); err != nil {
        app.Status = "failed"
        updateAppStatus(config, app)
        return
    }

    // Start the app
    if err := startApp(app.Name); err != nil {
        app.Status = "failed"
        updateAppStatus(config, app)
        return
    }

    app.Status = "running"
    updateAppStatus(config, app)
}

func removeAppHandler(config *Config) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        vars := mux.Vars(r)
        appName := vars["name"]

        registry, err := loadAppRegistry(config)
        if err != nil {
            http.Error(w, "Failed to load app registry", http.StatusInternalServerError)
            return
        }

        app, exists := registry.Apps[appName]
        if !exists {
            http.Error(w, "App not found", http.StatusNotFound)
            return
        }

        // Stop the app
        if err := stopApp(appName); err != nil {
            log.Printf("Error stopping app %s: %v", appName, err)
        }

        // Remove supervisor config
        removeFile(filepath.Join("/app/supervisor/programs", appName+".conf"))

        // Clean up app directory
        appDir := filepath.Join(config.DataDir, "apps", appName)
        removeDirectory(appDir)

        // Release port
        portManager, _ := loadPortManager(config)
        delete(portManager.Allocated, appName)
        savePortManager(config, portManager)

        // Remove from registry
        delete(registry.Apps, appName)
        saveAppRegistry(config, registry)

        // Update Caddy config
        updateCaddyConfig(config)

        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{"status": "removed"})
    }
}

// Utility functions would be implemented here...
```

### Scripts

```bash
#!/bin/bash
# scripts/deploy-app.sh

set -e

APP_NAME="$1"
REPO_URL="$2"
PORT="$3"
BRANCH="${4:-main}"

if [ -z "$APP_NAME" ] || [ -z "$REPO_URL" ] || [ -z "$PORT" ]; then
    echo "Usage: $0 <app_name> <repo_url> <port> [branch]"
    exit 1
fi

APP_DIR="/app/data/apps/$APP_NAME"
LOG_FILE="/app/data/logs/deploy-$APP_NAME.log"

echo "Deploying $APP_NAME from $REPO_URL on port $PORT" | tee "$LOG_FILE"

# Create app directory
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Clone repository
echo "Cloning repository..." | tee -a "$LOG_FILE"
if [ -d ".git" ]; then
    git fetch origin
    git reset --hard "origin/$BRANCH"
else
    git clone -b "$BRANCH" "$REPO_URL" .
fi

# Install dependencies and build
echo "Building application..." | tee -a "$LOG_FILE"
if [ -f "package.json" ]; then
    npm ci
    npm run build 2>&1 | tee -a "$LOG_FILE"
fi

if [ -f "backend/go.mod" ]; then
    cd backend
    go mod download
    CGO_ENABLED=0 go build -tags production -o "../$APP_NAME" 2>&1 | tee -a "$LOG_FILE"
    cd ..
fi

# Make binary executable
chmod +x "$APP_NAME"

# Create data directory for PocketBase
mkdir -p "pb_data"

echo "Deployment completed successfully" | tee -a "$LOG_FILE"
```

```bash
#!/bin/bash
# scripts/generate-caddyfile.sh

set -e

DATA_DIR="${DATA_DIR:-/app/data}"
DOMAIN_NAME="${DOMAIN_NAME:-lab.localhost}"

APPS_FILE="$DATA_DIR/apps.json"
CADDYFILE="$DATA_DIR/caddy/Caddyfile"

# Create caddy directory
mkdir -p "$(dirname "$CADDYFILE")"

# Start Caddyfile
cat > "$CADDYFILE" << EOF
# Auto-generated Caddyfile for Lab Server
# Do not edit manually - managed by lab-manager

# Health check endpoint
$DOMAIN_NAME {
    respond /health "OK" 200
    respond "Lab Server is running" 200
}

# Management API
$DOMAIN_NAME:9000 {
    reverse_proxy localhost:9000
}

EOF

# Add app configurations
if [ -f "$APPS_FILE" ]; then
    # Extract app configurations and add to Caddyfile
    jq -r '.apps | to_entries[] | "\(.value.subdomain).'$DOMAIN_NAME' { reverse_proxy localhost:\(.value.port) }"' "$APPS_FILE" >> "$CADDYFILE"
fi

echo "Generated Caddyfile with $(grep -c "reverse_proxy" "$CADDYFILE" || echo 0) app routes"

# Reload Caddy if it's running
if pgrep caddy > /dev/null; then
    curl -X POST "http://localhost:2019/load" \
         -H "Content-Type: text/caddyfile" \
         --data-binary @"$CADDYFILE" || echo "Failed to reload Caddy"
fi
```

## Deployment Process

### Initial Setup

1. **Create Lab Server Repository**
   ```bash
   mkdir lab-server
   cd lab-server
   git init
   
   # Copy all the files from above sections
   # Commit the initial setup
   git add .
   git commit -m "Initial lab server setup"
   ```

2. **Deploy to Fly.io**
   ```bash
   # Create Fly.io app
   fly apps create your-lab-server
   
   # Create volume for persistent data
   fly volumes create lab_data --region ord --size 50
   
   # Deploy the application
   fly deploy
   
   # Check status
   fly status
   fly logs
   ```

3. **Configure DNS**
   ```bash
   # Add your domain to Fly.io
   fly domains add lab.yourdomain.com
   
   # Set up wildcard DNS
   # Add CNAME: *.lab.yourdomain.com -> your-lab-server.fly.dev
   ```

### Deploying Your First App

1. **Deploy via API**
   ```bash
   # Deploy a PocketBase app
   curl -X POST https://lab.yourdomain.com:9000/api/deploy \
     -H "Content-Type: application/json" \
     -d '{
       "repository": "https://github.com/yourusername/your-pocketbase-app",
       "subdomain": "myapp"
     }'
   ```

2. **Check Deployment Status**
   ```bash
   # List all apps
   curl https://lab.yourdomain.com:9000/api/apps
   
   # Get specific app info
   curl https://lab.yourdomain.com:9000/api/apps/myapp
   
   # View app logs
   curl https://lab.yourdomain.com:9000/api/apps/myapp/logs
   ```

3. **Access Your App**
   - Visit: `https://myapp.lab.yourdomain.com`
   - PocketBase admin: `https://myapp.lab.yourdomain.com/_/`

### Removing an App

```bash
# Remove app completely
curl -X DELETE https://lab.yourdomain.com:9000/api/apps/myapp

# This will:
# 1. Stop the PocketBase process
# 2. Remove supervisor configuration
# 3. Clean up app files
# 4. Release the allocated port
# 5. Update Caddy configuration
# 6. Remove SSL certificates
```

## App Management System

### API Endpoints

#### GET /api/apps
Lists all deployed apps with their status.

**Response:**
```json
{
  "apps": {
    "myapp": {
      "name": "myapp",
      "repository": "https://github.com/user/repo",
      "port": 8091,
      "status": "running",
      "created_at": "2024-01-01T12:00:00Z",
      "last_deploy": "2024-01-01T12:00:00Z",
      "subdomain": "myapp"
    }
  }
}
```

#### POST /api/deploy
Deploys a new app from a Git repository.

**Request:**
```json
{
  "repository": "https://github.com/username/pocketbase-app",
  "subdomain": "myapp",
  "branch": "main"
}
```

**Response:**
```json
{
  "name": "myapp",
  "repository": "https://github.com/username/pocketbase-app",
  "port": 8091,
  "status": "deploying",
  "created_at": "2024-01-01T12:00:00Z",
  "subdomain": "myapp"
}
```

#### GET /api/apps/{name}
Gets information about a specific app.

#### DELETE /api/apps/{name}
Removes an app completely.

#### POST /api/apps/{name}/restart
Restarts a specific app.

#### GET /api/apps/{name}/logs
Gets recent logs for an app.

**Query Parameters:**
- `lines`: Number of log lines to return (default: 100)
- `follow`: Stream logs (default: false)

### Port Management

The system automatically allocates ports starting from 8091:

```json
{
  "allocated": {
    "myapp": 8091,
    "anotherapp": 8092
  },
  "next_port": 8093
}
```

Ports are released when apps are removed and can be reused.

### App Requirements

For an app to work with this system, it should:

1. **Be a PocketBase application** with the standard structure
2. **Have a Dockerfile** or be buildable with standard commands
3. **Support environment variables** for configuration:
   - `DB_DIR` - Database directory
   - `PORT` - HTTP port (will be set automatically)
4. **Include health checks** (PocketBase provides `/api/health`)

Example app structure:
```
your-pocketbase-app/
├── backend/
│   ├── main.go
│   ├── go.mod
│   └── go.sum
├── frontend/
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── Dockerfile (optional)
└── README.md
```

## Caddy Configuration

### Dynamic Configuration Management

The system generates Caddy configuration dynamically based on deployed apps:

```caddyfile
# Auto-generated Caddyfile
lab.yourdomain.com {
    respond /health "OK" 200
    respond "Lab Server is running" 200
}

lab.yourdomain.com:9000 {
    reverse_proxy localhost:9000
}

myapp.lab.yourdomain.com {
    reverse_proxy localhost:8091
}

anotherapp.lab.yourdomain.com {
    reverse_proxy localhost:8092
}
```

### SSL Certificate Management

Caddy automatically handles SSL certificates:
- Obtains certificates from Let's Encrypt
- Automatically renews certificates
- Supports wildcard certificates for `*.lab.yourdomain.com`

### Configuration Reloading

When apps are deployed or removed, Caddy configuration is updated without downtime:

```bash
# Reload configuration
curl -X POST "http://localhost:2019/load" \
     -H "Content-Type: text/caddyfile" \
     --data-binary @/app/data/caddy/Caddyfile
```

## Monitoring & Debugging

### Log Files

All logs are stored in `/app/data/logs/`:
```
/app/data/logs/
├── supervisord.log          # Supervisor main log
├── caddy.log               # Caddy access log
├── caddy.error.log         # Caddy error log
├── lab-manager.log         # API server log
├── lab-manager.error.log   # API server errors
├── deploy-myapp.log        # App deployment logs
└── myapp.log              # Individual app logs
```

### Accessing Logs

**Via Fly.io:**
```bash
fly logs                    # All logs
fly logs --app your-lab-server
```

**Via API:**
```bash
# Get app logs
curl https://lab.yourdomain.com:9000/api/apps/myapp/logs?lines=100

# Stream logs
curl https://lab.yourdomain.com:9000/api/apps/myapp/logs?follow=true
```

**Direct SSH:**
```bash
fly ssh console
tail -f /app/data/logs/myapp.log
```

### Health Checks

**System Health:**
```bash
curl https://lab.yourdomain.com/health
```

**Individual App Health:**
```bash
curl https://myapp.lab.yourdomain.com/api/health
```

**Service Status:**
```bash
# SSH into the server
fly ssh console

# Check supervisor status
supervisorctl status

# Check individual services
supervisorctl status caddy
supervisorctl status lab-manager
supervisorctl status myapp
```

### Common Issues & Solutions

#### App Won't Start
1. Check deployment logs: `curl lab.yourdomain.com:9000/api/apps/myapp/logs`
2. Verify binary exists: `ls /app/data/apps/myapp/`
3. Check supervisor config: `supervisorctl status myapp`
4. Manual restart: `supervisorctl restart myapp`

#### SSL Certificate Issues
1. Check Caddy logs: `tail -f /app/data/logs/caddy.error.log`
2. Verify DNS configuration: `nslookup myapp.lab.yourdomain.com`
3. Check Caddy config: `cat /app/data/caddy/Caddyfile`
4. Reload Caddy: `/app/scripts/generate-caddyfile.sh`

#### Port Conflicts
1. Check port allocation: `cat /app/data/ports.json`
2. Verify processes: `netstat -tlnp | grep 809`
3. Reset port manager if needed (manual intervention required)

#### Git Clone Failures
1. Check repository URL and accessibility
2. Verify SSH keys or tokens for private repos
3. Check deployment logs for specific error messages
4. Ensure branch exists: default is `main`

### Debugging Commands

```bash
# SSH into the server
fly ssh console

# Check all running processes
ps aux | grep -E "(caddy|lab-manager|pocketbase)"

# Check port usage
netstat -tlnp | grep :80

# Restart services
supervisorctl restart all
supervisorctl restart caddy
supervisorctl restart lab-manager

# Manual app deployment test
/app/scripts/deploy-app.sh testapp https://github.com/user/repo 8095

# Check Caddy configuration
caddy validate --config /app/data/caddy/Caddyfile

# Test API endpoints
curl localhost:9000/api/apps
curl localhost:8080/health
```

## Production Considerations

### Security

1. **API Security**
   - Add authentication to lab-manager API
   - Use API keys or JWT tokens
   - Restrict access by IP or VPN

2. **Git Repository Access**
   ```bash
   # For private repositories, set up SSH keys or tokens
   export GITHUB_TOKEN="your_token"
   # Or configure SSH keys in the container
   ```

3. **Resource Limits**
   - Set memory/CPU limits per app in supervisor configs
   - Monitor resource usage
   - Implement app quotas

### Backup Strategy

1. **Data Backup**
   ```bash
   # Create snapshot of Fly.io volume
   fly volumes snapshots create lab_data
   
   # List snapshots
   fly volumes snapshots list lab_data
   
   # Restore from snapshot
   fly volumes create lab_data_restored --snapshot snap_id
   ```

2. **Configuration Backup**
   ```bash
   # Backup app registry and configs
   tar -czf backup.tar.gz /app/data/apps.json /app/data/ports.json /app/data/caddy/
   ```

### Scaling Considerations

1. **Vertical Scaling**
   ```toml
   # Update fly.toml
   [[vm]]
     memory = "4gb"
     cpu_kind = "shared"
     cpus = 4
   ```

2. **Resource Monitoring**
   ```bash
   # Monitor resource usage
   fly metrics
   htop  # Inside the container
   ```

3. **App Limits**
   - Monitor number of apps vs available resources
   - Set maximum apps per server
   - Implement cleanup policies for unused apps

### High Availability

1. **Multiple Regions**
   ```bash
   # Scale to multiple regions
   fly scale count 2 --region ord,dfw
   ```

2. **Health Monitoring**
   - Implement comprehensive health checks
   - Set up external monitoring (UptimeRobot, etc.)
   - Configure alerts for service failures

3. **Graceful Degradation**
   - Handle individual app failures gracefully
   - Implement circuit breakers
   - Provide status pages

### Cost Optimization

1. **Resource Allocation**
   - Start with smaller VM sizes
   - Monitor actual usage
   - Scale based on demand

2. **Storage Management**
   - Implement cleanup policies for old deployments
   - Archive unused app data
   - Monitor volume usage

3. **Auto-scaling**
   ```toml
   # In fly.toml
   [http_service]
     auto_stop_machines = "stop"
     auto_start_machines = true
     min_machines_running = 1
   ```

This completes the comprehensive guide for setting up a multi-PocketBase lab server on Fly.io with Caddy. The system provides a cost-effective way to host multiple small SaaS applications with proper isolation, SSL termination, and easy management through a REST API.