# VPS Setup Repository - GitLab Deployment Guide

## Overview

This is a **production-ready VPS setup repository** designed for automated deployment of modern web infrastructure on Ubuntu 24.04 systems. It includes:

- 🔧 **Dynamic SSH Configuration** - Works with any remote host via environment variables
- 🚀 **Modular Deployment Scripts** - Quick setup for web, database, dev, and production stacks
- 📦 **Service Management** - Individual service installation (Node.js, PostgreSQL, NGINX, etc.)
- 🔐 **Security-First** - Environment-driven configuration, no hardcoded credentials
- 📚 **Comprehensive Documentation** - Setup guides, checklists, and deployment patterns

---

## Quick Start

### 1. Clone Repository

```bash
# Private GitLab (ensure SSH access is configured)
git clone git@gitlab.your-domain.com:your-org/vps-setup.git
cd vps-setup

# Or via HTTPS with token
git clone https://gitlab-token:your-token@gitlab.your-domain.com/your-org/vps-setup.git
cd vps-setup
```

### 2. Configure Environment

Create a `.env` file with your deployment configuration:

```bash
cat > .env << EOF
# SSH Configuration
SSH_HOST="your-vps.example.com"           # VPS IP or hostname
SSH_USER="ubuntu"                          # SSH user
SSH_PORT="22"                              # SSH port
SSH_KEY="~/.ssh/id_rsa"                   # Path to SSH private key

# Tailscale Configuration
TS_AUTHKEY="tskey_..."                    # From https://login.tailscale.com/admin/settings/keys
TS_HOSTNAME="prod-db"                     # Tailscale device name

# Database Configuration
POSTGRES_PASSWORD="secure-password"        # PostgreSQL password
POSTGRES_USER="postgres"                   # Default PostgreSQL user
MYSQL_ROOT_PASSWORD="mysql-password"       # MySQL root password

# Node.js Configuration
NODE_VERSION="18.17.0"                    # Node.js version
NPM_GLOBAL_PACKAGES="pm2 pm2-logrotate"   # Global npm packages
EOF

# IMPORTANT: Never commit .env file
echo ".env" >> .gitignore.local
```

### 3. Deploy VPS

**For Remote Deployment:**

```bash
# Deploy with configuration (web, database, dev, production, etc.)
./scripts/deploy.sh web

# Or specific configuration
./scripts/deploy.sh production
```

**For Manual Setup:**

```bash
# Connect to VPS
ssh -i ~/.ssh/id_rsa ubuntu@your-vps.example.com

# Copy scripts to VPS
scp -r scripts/ ubuntu@your-vps.example.com:~/

# Run VPS setup
ssh ubuntu@your-vps.example.com "sudo bash ~/scripts/vps-setup.sh"

# Install specific service
ssh ubuntu@your-vps.example.com "bash ~/scripts/services.sh nginx"
```

---

## Deployment Configurations

### Configuration Types

| Config | Purpose | Includes |
|--------|---------|----------|
| **minimal** | Base OS setup | Updates, SSH, firewall |
| **web** | Web server stack | NGINX, SSL, Node.js |
| **database** | Database server | PostgreSQL, Redis, backups |
| **dev** | Development environment | Tools, Docker, debuggers |
| **production** | Full production stack | Everything + monitoring |
| **cicd** | CI/CD runner | GitLab Runner, agents |
| **full** | Everything | All services and tools |

### Deploy Specific Configuration

```bash
# Web server
./scripts/deploy.sh web

# Database server
./scripts/deploy.sh database

# Full production stack
./scripts/deploy.sh production
```

---

## Service Installation

Install individual services on an existing VPS:

```bash
# From local VPS
./scripts/services.sh tailscale
./scripts/services.sh nodejs
./scripts/services.sh postgres
./scripts/services.sh nginx
./scripts/services.sh mysql
./scripts/services.sh redis
./scripts/services.sh docker

# Or remote (via SSH)
ssh ubuntu@your-vps.example.com "bash ~/scripts/services.sh postgresql"
```

---

## SSH Configuration

### Method 1: Environment Variable (Recommended)

```bash
export SSH_HOST="your-vps.example.com"
./scripts/deploy.sh web
```

### Method 2: Command Line Argument

```bash
SSH_HOST="your-vps.example.com" ./scripts/deploy.sh web
```

### Method 3: .env File

```bash
# Create .env with SSH_HOST
cat > .env << EOF
SSH_HOST="your-vps.example.com"
SSH_USER="ubuntu"
SSH_PORT="22"
EOF

./scripts/deploy.sh web
```

### Method 4: SSH Config File

```bash
# ~/.ssh/config
Host prod-db
    HostName your-vps.example.com
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa

# Then reference it
SSH_HOST="prod-db" ./scripts/deploy.sh web
```

---

## Security Best Practices

### 1. Never Commit Secrets

```bash
# These files are automatically excluded
.env              # Your environment configuration
.env.*            # All env variants
*.key, *.pem      # SSL/SSH keys
*.sql, *.dump     # Database dumps
secrets.json      # Any secret files
```

### 2. Use Environment Variables for Sensitive Data

```bash
# ✅ Good - Use variables
export DB_PASSWORD="secure-password"
./scripts/deploy.sh database

# ❌ Bad - Hardcoded in files
cat > script.sh << EOF
DB_PASSWORD="hardcoded-password"  # Never do this!
EOF
```

### 3. SSH Key Authentication

```bash
# Copy your SSH public key to VPS
ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@your-vps.example.com

# Verify SSH access (should not prompt for password)
ssh ubuntu@your-vps.example.com "echo 'SSH works!'"
```

### 4. Tailscale for Secure Access

```bash
# Get auth key from: https://login.tailscale.com/admin/settings/keys
export TS_AUTHKEY="tskey_..."

# Deploy with Tailscale enabled
./scripts/deploy.sh production

# Access via Tailscale IP instead of public IP
ssh ubuntu@prod-db.tail1234.ts.net
```

---

## Typical Deployment Scenarios

### Scenario 1: Simple Web Server

```bash
# 1. Prepare environment
cat > .env << EOF
SSH_HOST="web-server.example.com"
SSH_USER="ubuntu"
EOF

# 2. Deploy web stack
./scripts/deploy.sh web

# 3. Deploy Node.js app
# Copy your app to /var/www/app
# Run: npm install && npm start
```

### Scenario 2: Database Server

```bash
# 1. Configure database
cat > .env << EOF
SSH_HOST="db-server.example.com"
POSTGRES_PASSWORD="secure-db-password"
EOF

# 2. Deploy database stack
./scripts/deploy.sh database

# 3. Import data
# scp your-backup.sql ubuntu@db-server:~/
# ssh ubuntu@db-server "PGPASSWORD='secure-db-password' psql -U postgres < ~/your-backup.sql"
```

### Scenario 3: Production Stack

```bash
# 1. Full configuration
cat > .env << EOF
SSH_HOST="prod.example.com"
SSH_USER="ubuntu"
TS_AUTHKEY="tskey_..."
POSTGRES_PASSWORD="prod-db-password"
NODE_VERSION="18.17.0"
EOF

# 2. Deploy full stack
./scripts/deploy.sh production

# 3. Deploy application
# Clone app repo
# Install dependencies (npm install)
# Configure PM2
# Start with PM2: pm2 start app.js
```

---

## Documentation Files

### Getting Started
- 📖 **README.md** - Overview and quick start
- 🚀 **QUICK-START.md** - Fast setup guide
- ⚡ **00-README-FIRST.md** - Initial setup checklist

### Deployment Guides
- 📋 **IMPLEMENTATION-COMPLETE.md** - Feature checklist
- 🔐 **SECURITY-AUDIT-FINAL.md** - Security review
- 📚 **docs/NEXTJS-DEPLOYMENT.md** - Next.js deployment
- 📚 **docs/SERVER-CONTEXT.md** - Server architecture

### Service-Specific
- 🐘 **docs/BASTION-SETUP.md** - Bastion host setup
- 📊 **POSTGRESQL-SETUP-CHECKLIST.sh** - PostgreSQL guide
- 🚀 **conf/detoxnearme-strapi/edge-pm2.md** - Strapi deployment

---

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -v ubuntu@your-vps.example.com "echo 'Connection test'"

# Verify SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Check SSH config
cat ~/.ssh/config | grep -A 5 "your-vps"
```

### Permission Denied Errors

```bash
# Ensure script is executable
chmod +x scripts/*.sh

# Run with bash explicitly
bash scripts/deploy.sh web

# For remote execution, ensure sudo works
ssh ubuntu@your-vps.example.com "sudo whoami"
```

### Missing Environment Variables

```bash
# Verify .env is loaded
cat .env | grep SSH_HOST

# Source .env manually
source .env
echo "$SSH_HOST"

# Check if .env file exists
test -f .env && echo "✅ .env exists" || echo "❌ .env not found"
```

---

## Continuous Deployment (CI/CD)

### GitLab CI/CD Integration

```yaml
# .gitlab-ci.yml
stages:
  - deploy

deploy_production:
  stage: deploy
  script:
    - chmod +x scripts/*.sh
    - SSH_HOST="$PROD_HOST" SSH_USER="$PROD_USER" ./scripts/deploy.sh production
  environment:
    name: production
  only:
    - main
```

### GitLab Runner Setup

```bash
# From VPS, install GitLab Runner
./scripts/services.sh gitlab-runner

# Register runner with GitLab
sudo gitlab-runner register
```

---

## Maintenance

### Regular Backups

```bash
# Database backup
ssh ubuntu@your-vps.example.com "\
  PGPASSWORD='$DB_PASSWORD' pg_dump -U postgres mydatabase > backup.sql"

# Download backup
scp ubuntu@your-vps.example.com:~/backup.sql ./backups/
```

### Updates and Patches

```bash
# SSH into VPS
ssh ubuntu@your-vps.example.com

# Update system
sudo apt update && sudo apt upgrade -y

# Update Node.js
nvm install 18.17.0 && nvm alias default 18.17.0

# Restart services
sudo systemctl restart nginx
pm2 restart all
```

### Monitor Services

```bash
# SSH into VPS
ssh ubuntu@your-vps.example.com

# Check service status
systemctl status nginx
systemctl status postgresql
pm2 status

# View logs
pm2 logs
sudo journalctl -u nginx -f
```

---

## Getting Help

### Check Logs

```bash
# SSH to VPS
ssh ubuntu@your-vps.example.com

# View script output
cat ~/vps-setup.log

# Check service status
sudo systemctl status [service]

# View PM2 logs
pm2 logs [app]
```

### Debug Script Execution

```bash
# Run with debug output
bash -x scripts/deploy.sh web

# Check script syntax
bash -n scripts/vps-setup.sh
```

### Verify Configuration

```bash
# SSH to VPS and check
ssh ubuntu@your-vps.example.com

# Check installed services
which nginx postgresql node npm

# Check versions
nginx -v
psql --version
node -v
npm -v
```

---

## Repository Structure

```
vps-setup/
├── scripts/
│   ├── vps-setup.sh           # Main setup script
│   ├── deploy.sh              # Deployment orchestrator
│   ├── services.sh            # Individual service installers
│   ├── backup-dotfiles.sh     # Backup utilities
│   ├── deploy-bastion.sh      # Bastion host deployment
│   └── NEXTJS-FUNCTIONS.sh    # Next.js specific functions
├── conf/
│   ├── www.theedgetreatment.com/
│   │   ├── nginx/             # NGINX configurations
│   │   └── ssl/               # SSL certificate configs
│   └── detoxnearme-strapi/    # Strapi-specific config
├── docs/
│   ├── NEXTJS-DEPLOYMENT.md   # Next.js guide
│   ├── BASTION-SETUP.md       # Bastion guide
│   ├── MIGRATION-CHECKLIST.md # Migration steps
│   └── SERVER-CONTEXT.md      # Architecture
├── README.md                  # Main documentation
├── QUICK-START.md             # Fast start guide
└── .gitignore                 # Excludes sensitive files
```

---

## Contributing

### Adding New Services

1. Add function to `scripts/services.sh`
2. Follow existing patterns (logging, error handling)
3. Test on Ubuntu 24.04
4. Document in this guide

### Updating Documentation

1. Edit relevant `.md` file
2. Keep examples up-to-date
3. Remove hardcoded secrets
4. Commit with clear message

---

## License

This project is private. Access restricted to team members.

---

## Support

For issues or questions:

1. Check relevant documentation file
2. Review script comments and logs
3. Test in development environment first
4. Contact team lead for production deployments

