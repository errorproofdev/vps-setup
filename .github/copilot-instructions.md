# Copilot Instructions - VPS Setup Codebase

## Project Overview

This repository provides **production-ready shell scripts for automated VPS deployment** on Ubuntu 24.04, supporting local and remote execution via dynamic SSH. It orchestrates deployment of three Next.js applications and a Strapi CMS across multiple VPS instances.

**Key Insight**: The architecture separates concerns into **infrastructure layer** (vps-setup, deploy, services) and **application layer** (conf/ templates for three Next.js apps + Strapi backend).

## Quick Architecture Map

```
vps-setup.sh (Core) → deploy.sh (Profiles) → services.sh (Modules)
    ↓                     ↓
Core VPS config    • minimal/web/database/dev/production
• SSH hardening    • Remote SSH support
• Firewall (UFW)   • Environment-driven config
• Tailscale VPN    • Modular service selection
```

**Application Stack**:

- **node-steelgem**: Hosts three Next.js apps (DetoxNearMe, Edge Treatment, Forge Recovery)
- **sql-steelgem**: PostgreSQL + Strapi CMS for DetoxNearMe

## Critical Developer Workflows

### Making Changes to Scripts

**Always follow this pattern:**

```bash
# 1. Test syntax (prevents runtime failures)
bash -n scripts/vps-setup.sh

# 2. Test in isolated VM/container (never production first)
vagrant up  # or docker run ubuntu:24.04

# 3. Validate service status after changes
systemctl status service_name
journalctl -u service_name -n 50

# 4. Verify configuration before restarting services
nginx -t          # For NGINX changes
pm2 describe app  # For PM2 changes
```

### Deploying Changes to VPS

```bash
# Method 1: Direct environment variable (simplest)
SSH_HOST="192.168.1.100" ./scripts/deploy.sh web

# Method 2: .env file (for multiple variables)
cat > .env << EOF
SSH_HOST="sql-steelgem"
POSTGRES_PASSWORD="secure-pw"
TAILSCALE_AUTH_KEY="tskey_..."
EOF
./scripts/deploy.sh production

# Method 3: SSH config alias
# Edit ~/.ssh/config with Host entry, then:
SSH_HOST="sql-steelgem" ./scripts/deploy.sh database
```

### Common Development Tasks

```bash
# Add a new service installer
# Edit: scripts/services.sh
# Pattern: Function named install_servicename() with error handling

# Add deployment profile
# Edit: scripts/deploy.sh
# Pattern: Add case branch in main(), calls service functions

# Update NGINX config for existing app
# Edit: conf/node-steelgem/detoxnearme/nginx/detoxnearme.conf
# Test: nginx -t && systemctl reload nginx

# Check PM2 app status
pm2 list
pm2 logs detoxnearme --lines 50
```

## Project-Specific Conventions

### Shell Script Standards

**Every script must have:**

1. **Header and shebang**

   ```bash
   #!/bin/bash
   # Purpose: Brief description
   set -euo pipefail
   ```

2. **Standardized logging** (defined in every script)

   ```bash
   log()      # Blue info - use for progress/status
   success()  # Green - use after successful operations
   warning()  # Yellow - use for non-critical issues
   error()    # Red - use before returning 1
   ```

3. **Function organization**
   - Max 50 lines per function
   - Descriptive names: `install_nginx()` not `setup()`
   - All variables in functions must be `local`
   - Comments explaining complex logic

4. **Error handling on external commands**

   ```bash
   mkdir -p /tmp/mydir || {
       error "Failed to create directory"
       return 1
   }
   ```

### Configuration Philosophy

**All runtime configuration is environment-driven** - never hardcoded in scripts:

- SSH credentials: `SSH_HOST`, `SSH_USER`, `SSH_PORT`
- Service passwords: `POSTGRES_PASSWORD`, `MYSQL_PASSWORD`
- Auth tokens: `TAILSCALE_AUTH_KEY`, `CONTENTFUL_ACCESS_TOKEN`
- Feature flags: `INSTALL_NGINX=true`, `UBUNTU_SUDO=false`

**Configuration priority** (in order):

1. Command-line environment variables (highest)
2. `.env` file in script directory
3. `~/.ssh/config` for SSH hosts
4. Script defaults (lowest)

### SSH Support Pattern

Scripts designed for **dual execution** (local or remote):

```bash
# Local: SSH_HOST empty or unset
sudo ./scripts/vps-setup.sh           # Runs locally as root

# Remote: SSH_HOST specified
SSH_HOST="prod-server" \
SSH_USER="ubuntu" \
./scripts/deploy.sh web               # Executed via SSH on remote
```

## NGINX Configuration Patterns

All Next.js apps follow the **try-files + proxy pattern**:

### Key Pattern Elements

```nginx
# 1. Upstream definition (connect to PM2 Node.js app)
upstream app_name {
    server 127.0.0.1:3000;  # Matches PM2 port
    keepalive 64;            # Connection pooling
}

# 2. HTTP → HTTPS redirect
server {
    listen 80;
    server_name domain.com www.domain.com;
    location / {
        return 301 https://domain.com$request_uri;  # Always root domain
    }
}

# 3. HTTPS server (root domain only)
server {
    listen 443 ssl http2;    # HTTP/2 for performance
    server_name domain.com;   # NOT www subdomain

    # SSL with Cloudflare origin certificates
    ssl_certificate /etc/ssl/certs/domain.com/cert.pem;
    ssl_certificate_key /etc/ssl/certs/domain.com/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # Next.js static files first
    root /var/www/apps/appname/.next/static;

    # Try static files before proxying
    location / {
        try_files $uri @proxy;
    }

    # Proxy to PM2 app
    location @proxy {
        proxy_pass http://app_name;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;  # WebSocket
        proxy_set_header Connection "upgrade";
    }
}
```

### Real Example: DetoxNearMe

File: `conf/node-steelgem/detoxnearme/nginx/detoxnearme.com.conf`

- Proxy to port 3001 (DetoxNearMe app)
- Cloudflare SSL certificates at `/etc/ssl/detoxnearme/`
- Legacy URL redirect: `/withdrawal-symptoms/` → `/detox/`
- Security headers: X-Frame-Options, X-Content-Type-Options, CSP

### Critical NGINX Changes

When making NGINX changes:

```bash
# 1. Edit conf file
vim conf/node-steelgem/appname/nginx/appname.conf

# 2. Test syntax (MUST pass)
sudo nginx -t

# 3. Reload (zero-downtime)
sudo systemctl reload nginx

# 4. Verify upstream still responds
curl -I https://appname.domain.com
```

Do NOT use `restart` - use `reload` for zero-downtime config changes.

## PM2 Process Management Patterns

All Node.js applications are managed by PM2 with consistent configuration:

### Process Modes

**Fork Mode** (current): Single process instance per app

```bash
pm2 start npm --name "detoxnearme" -- run start
```

**Cluster Mode** (for scaling): Multiple instances, load balanced

```bash
pm2 start npm --name "detoxnearme" -i 2 -- run start  # 2 instances
```

### Monitoring Commands

```bash
# List all processes
pm2 list

# Monitor CPU/Memory
pm2 monit

# View logs with grep
pm2 logs detoxnearme --lines 100
pm2 logs detoxnearme --err --lines 50  # Errors only

# Describe individual process
pm2 describe detoxnearme

# Check environment variables
pm2 env detoxnearme

# Real-time metrics
pm2 trigger detoxnearme km:heapdump  # Generate heap dump
```

### PM2 Configuration per Server

**node-steelgem** (3 apps on ports 3000-3002):

```bash
pm2 start npm --name "detoxnearme" --cwd /var/www/apps/detoxnearme -- run start
pm2 start npm --name "edge" --cwd /var/www/apps/edge-nextjs -- run start
pm2 start npm --name "forge" --cwd /var/www/apps/forge-nextjs -- run start
```

**sql-steelgem** (Strapi only):

```bash
pm2 start npm --name "strapi" --cwd /home/ubuntu/strapi -- start
```

### Auto-start After VPS Reboot

```bash
# Save current PM2 configuration
pm2 save

# Install as startup service
pm2 startup

# Verify
sudo systemctl status pm2-ubuntu
```

### Restarting Apps Without Downtime

```bash
# Zero-downtime restart (fork mode)
pm2 restart detoxnearme

# Reload (cluster mode - graceful)
pm2 reload detoxnearme

# Watch file for auto-restart (development only)
pm2 watch detoxnearme --ignore node_modules
```

## Service Installation Patterns

### Adding a New Service

**Location**: `scripts/services.sh`

**Pattern**:

```bash
install_myservice() {
    log "Installing MyService..."

    # Update first
    apt-get update -y

    # Backup original config if modifying existing service
    [[ -f /etc/myservice/config ]] && \
        cp /etc/myservice/config /etc/myservice/config.backup.$(date +%Y%m%d)

    # Install
    apt-get install -y myservice-package

    # Configure
    cat > /etc/myservice/config << 'EOF'
    # Configuration here
    EOF

    # Validate
    myservice -t || { error "Config invalid"; return 1; }

    # Enable and start
    systemctl enable myservice
    systemctl restart myservice

    success "MyService installed and started"
}
```

### Deployment Profiles

**Location**: `scripts/deploy.sh`

Profiles combine service installations:

- **minimal**: System updates, SSH, UFW only
- **web**: nginx, Node.js/NVM, PM2, SSL support
- **database**: PostgreSQL, Redis, backup utilities
- **dev**: Development tools, Docker, debuggers
- **production**: web + database + monitoring
- **cicd**: CI/CD tools, git webhooks
- **full**: Everything

## Server Architecture & Purposes

The infrastructure spans three dedicated servers:

### 🌐 node-steelgem (Production Web Server)

**Role**: Hosts all three Next.js applications via NGINX reverse proxy and PM2

**Characteristics**:

- Ubuntu 24.04 LTS, 4-core CPU, SSD storage
- NGINX for TLS termination and static asset serving
- Three Next.js apps on ports 3000-3002
- PM2 for process management and auto-restart
- Firewall: ports 22 (SSH), 80/443 (HTTP/HTTPS)

**Applications**:

- Port 3000: <www.detoxnearme.com> → `/var/www/apps/detoxnearme/`
- Port 3001: <www.theedgetreatment.com> → `/var/www/apps/edge-nextjs/`
- Port 3002: <www.theforgerecovery.com> → `/var/www/apps/forge-nextjs/`

### 🗄️ sql-steelgem (Production Database Server)

**Role**: PostgreSQL database + Strapi CMS backend

**Characteristics**:

- Ubuntu 24.04 LTS, isolated database-only server
- PostgreSQL 16 for application data
- Strapi CMS on port 3000 (internal access only)
- PM2 manages Strapi process
- Firewall: port 22 (SSH), 5432 (PostgreSQL, internal only)

**Services**:

- PostgreSQL: `postgresql://user:pass@sql-steelgem:5432/detoxnearme`
- Strapi CMS: <http://sql-steelgem:3000> (internal, behind NGINX on node-steelgem)

### 🔄 stg-steelgem (Staging Server)

**Role**: Pre-production testing environment mirroring node-steelgem

**Characteristics**:

- Identical configuration to node-steelgem (same base setup)
- Used for testing deployments before production
- Can test NGINX rewrites, PM2 clustering, SSL changes
- Lower resource requirements acceptable
- Firewall: same as production (22, 80, 443)

**Domains** (staging versions):

- stg.detoxnearme.com (port 3000)
- stg.theedgetreatment.com (port 3001)
- stg.theforgerecovery.com (port 3002)

**Setup**: `SSH_HOST="stg-steelgem" ./scripts/deploy.sh production`

## Application Deployment Map

### Three Next.js Applications

**Location**: `conf/node-steelgem/`

| App | Domain | Port | Framework | CMS | Database |
|-----|--------|------|-----------|-----|----------|
| DetoxNearMe | detoxnearme.com | 3000 | Pages Router | Strapi (sql-steelgem) | PostgreSQL |
| Edge Treatment | theedgetreatment.com | 3001 | App Router v14+ | Contentful | None |
| Forge Recovery | theforgerecovery.com | 3002 | App Router v14+ | Contentful | None |

Each app has:

- `.env.local.example` - Environment template
- `.nvmrc` - Node.js version (v20.19.5)
- `pm2.md` - Process management docs
- `nginx/*.conf` - Reverse proxy configuration

### Full Deployment Workflow: Production

**Phase 1: Base Server Setup**

```bash
# On node-steelgem and sql-steelgem
SSH_HOST="node-steelgem" ./scripts/vps-setup.sh
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
```

**Phase 2: Infrastructure (node-steelgem)**

```bash
# Install Node.js via NVM
SSH_HOST="node-steelgem" ./scripts/services.sh nvm

# Install NGINX for Next.js (reverse proxy, static serving)
SSH_HOST="node-steelgem" ./scripts/services.sh nextjs-nginx

# Install SSL certificates (Cloudflare origin certs)
SSH_HOST="node-steelgem" ./scripts/services.sh nextjs-ssl
```

**Phase 3: Database (sql-steelgem)**

```bash
# Install PostgreSQL
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql

# Create database for DetoxNearMe
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql-create-db detoxnearme

# Install and start Strapi CMS
SSH_HOST="sql-steelgem" ./scripts/services.sh strapi
```

**Phase 4: Deploy Applications (node-steelgem)**

```bash
# Copy application source code from edge-prod (via bastion pattern)
scp -r edge-prod:/home/ubuntu/current/detoxnearme node-steelgem:/var/www/apps/

# For each app:
# 1. Create .env.local with database/API credentials
# 2. Install dependencies: npm ci --production
# 3. Build: npm run build
# 4. Start with PM2
pm2 start npm --name "detoxnearme" -- run start

# Enable NGINX sites and reload
SSH_HOST="node-steelgem" sudo nginx -t && sudo systemctl reload nginx

# Verify health
curl -I https://www.detoxnearme.com
pm2 list
```

### Staging Deployment Pattern

Identical to production but with `stg-steelgem` server:

```bash
SSH_HOST="stg-steelgem" ./scripts/deploy.sh production

# Then deploy apps with staging domains
# (detoxnearme.com → stg.detoxnearme.com in NGINX config)
```

## Integration Points & Data Flows

### Production Network Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Client Bundle (CDN)                          │
│                    (Cloudflare Protection)                          │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
┌──────────────────── node-steelgem (443) ────────────────────────────┐
│ NGINX (TLS termination, static files, routing)                      │
├─────────────────────────────────────────────────────────────────────┤
│ ├─ detoxnearme.com → PM2:3000 → Node.js app                        │
│ │       ↓                                                             │
│ │   PostgreSQL (sql-steelgem:5432)                                  │
│ │                                                                     │
│ ├─ theedgetreatment.com → PM2:3001 → Node.js app                   │
│ │       ↓                                                             │
│ │   Contentful API (external)                                       │
│ │                                                                     │
│ └─ theforgerecovery.com → PM2:3002 → Node.js app                   │
│         ↓                                                             │
│     Contentful API (external)                                       │
└──────────────────────────────┬──────────────────────────────────────┘\n                               ↓\n┌──────────────────── sql-steelgem ─────────────────────────────────┐\n│ PostgreSQL:5432 ← node-steelgem apps (internal network only)      │\n│                                                                   │\n│ Strapi CMS:3000 → Reverse proxy on node-steelgem:cms.detox...  │\n└─────────────────────────────────────────────────────────────────┘\n```\n\n**Network Isolation**:\n- **node-steelgem ↔ sql-steelgem**: Private network (firewall blocks external access to 5432)\n- **Clients ↔ node-steelgem**: Public TLS, Cloudflare origin cert\n- **Developers ↔ nodes**: SSH only, Tailscale VPN optional\n\n**Critical Update Points**:\n- App port changes: Update `conf/node-steelgem/*/nginx/*.conf` upstream definition (line 1-3)\n- Database connection: Update `.env.local` files with `DATABASE_URL`\n- NGINX reload: `sudo systemctl reload nginx` (zero-downtime)\n- PM2 restart: `pm2 restart appname` (graceful with session draining)

### Firewall Rules Required

- **node-steelgem**: Ports 22 (SSH), 80 (HTTP → HTTPS), 443 (HTTPS), 3000-3002 (PM2 apps)
- **sql-steelgem**: Port 22 (SSH), 5432 (PostgreSQL, internal only)

Scripts automatically configure UFW:
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
```

## Key Files to Reference

When implementing features, consult these:

| Task | Reference File |
|------|-----------------|
| Add system configuration | [scripts/vps-setup.sh](scripts/vps-setup.sh) - see `configure_*` functions |
| Add service installer | [scripts/services.sh](scripts/services.sh) - follow `install_*` pattern |
| Add deployment profile | [scripts/deploy.sh](scripts/deploy.sh) - add case in main() |
| Update app deployment | [conf/node-steelgem/README.md](conf/node-steelgem/README.md) |
| NGINX reverse proxy | [conf/node-steelgem/detoxnearme/nginx/](conf/node-steelgem/detoxnearme/nginx/) |
| Process management | [conf/node-steelgem/detoxnearme/pm2.md](conf/node-steelgem/detoxnearme/pm2.md) |
| Deployment docs | [docs/NEXTJS-DEPLOYMENT.md](docs/NEXTJS-DEPLOYMENT.md) |

## Code Review Priorities

Before merging script changes, verify:

- [ ] Syntax valid: `bash -n scripts/mychanges.sh`
- [ ] `set -euo pipefail` present at top
- [ ] All variables quoted: `"$VAR"` not `$VAR`
- [ ] Functions use `local` for variables
- [ ] Error handling on external commands
- [ ] Config files backed up before modification
- [ ] Logging functions used consistently
- [ ] No hardcoded credentials (use environment variables)
- [ ] Tested on Ubuntu 24.04 (in VM before production)
- [ ] Documentation/README updated if adding features

## Common Debugging Commands

```bash
# Script syntax check
bash -n scripts/vps-setup.sh

# Trace script execution
bash -x scripts/deploy.sh web 2>&1 | head -100

# Check SSH connectivity before deployment
ssh -v ubuntu@target-server "echo 'test'"

# View service logs after deployment
journalctl -u nginx -n 50 --no-pager
journalctl -u pm2-ubuntu -n 50 --no-pager

# Test service configuration
nginx -t              # NGINX syntax
pm2 describe app-name # PM2 app status
systemctl status ssh  # Service status

# Check firewall rules
sudo ufw status verbose
```

## Environment Variables Reference

### SSH Configuration

| Var | Default | Example |
|-----|---------|---------|
| `SSH_HOST` | (empty) | `192.168.1.100` or `prod-server` |
| `SSH_USER` | `ubuntu` | `ubuntu` |
| `SSH_PORT` | `22` | `2222` |

### VPS Setup Variables

| Var | Default | Purpose |
|-----|---------|---------|
| `UBUNTU_USER` | `ubuntu` | System user name |
| `UBUNTU_SUDO` | `false` | Full sudo privileges |
| `INSTALL_NGINX` | `true` | Install NGINX |
| `INSTALL_TAILSCALE` | `true` | Install Tailscale VPN |
| `TAILSCALE_AUTH_KEY` | (empty) | Tailscale authentication |
| `TAILSCALE_HOSTNAME` | `node-steelgem` | VPN node name |

### Application Variables

Configured per app in `.env.local`:

**DetoxNearMe**: `DATABASE_URL`, `NEXT_PUBLIC_API_URL`, `NODE_ENV`

**Edge/Forge**: `CONTENTFUL_SPACE_ID`, `CONTENTFUL_ACCESS_TOKEN`, `CONTENTFUL_ENVIRONMENT`, `NODE_ENV`

## Architecture Decision Notes

**Why dynamic SSH support?** Enables scripts to run on any server without modification - configuration drives behavior.

**Why modular service installers?** Allows users to install only needed services, reducing deployment time and attack surface.

**Why environment-driven config?** Never commits secrets to git; supports multiple deployment environments (dev, staging, production) with same code.

**Why PM2 for Next.js apps?** Provides zero-downtime reloads, clustering, auto-restart, centralized logging - critical for production reliability.

**Why Cloudflare origin certificates?** Secure end-to-end encryption when Cloudflare acts as CDN/WAF.
