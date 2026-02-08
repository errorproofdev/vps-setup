# Node-Steelgem VPS Setup Guide

**Server Purpose**: NextJS Application Hosting Server
**Target OS**: Ubuntu 24.04 LTS
**SSH Alias**: `node-steelgem`
**Server Resources**: 4 CPU cores, optimized for Node.js workloads

---

## 📋 Overview

This VPS will host **3 NextJS applications** with different architectures:

| Application | Domain | Port | Architecture | CMS/Data Source |
|------------|--------|------|--------------|-----------------|
| **DetoxNearMe** | detoxnearme.com | 3000 | Pages Router | PostgreSQL @ cms.detoxnearme.com |
| **Edge Treatment** | <www.theedgetreatment.com> | 3001 | App Router (v14-v15) | Contentful CMS |
| **Forge Recovery** | theforgerecovery.com | 3002 | App Router (v14-v15) | Contentful CMS |

---

## 🎯 Architecture Highlights

### Multi-Architecture Support

- **Pages Router** (DetoxNearMe): Traditional NextJS routing with `pages/` directory
- **App Router** (Edge + Forge): Modern NextJS 14-15 with `app/` directory, React Server Components

### Resource Optimization

- **PM2 Cluster Mode**: Leverage all 4 CPU cores
- **NGINX Load Balancing**: Distribute traffic efficiently across PM2 instances
- **Shared NGINX Instance**: Single NGINX server handling all 3 domains
- **Connection Pooling**: Keepalive connections to reduce overhead

---

## 🚀 Quick Start Deployment

### Step 1: Initial VPS Setup

```bash
# From your local machine (bastion)
scp -r scripts/ root@node-steelgem:/root/vps-setup/

# SSH into server
ssh root@node-steelgem

# Run base system setup
cd /root/vps-setup
sudo ./scripts/vps-setup.sh
```

### Step 2: Install Node.js Environment

```bash
# Install NVM + Node.js LTS + PM2
sudo ./scripts/services.sh nvm
```

### Step 3: Deploy Applications (Automated)

```bash
# Deploy all three applications
sudo ./scripts/services.sh deploy-node-steelgem
```

---

## 📂 Directory Structure

```
/var/www/apps/
├── detoxnearme/
│   ├── .next/                    # NextJS build output (pages router)
│   ├── .nvmrc                    # Node version specification
│   ├── .env.local                # Environment variables
│   ├── pages/                    # Pages router directory
│   ├── public/                   # Static assets
│   ├── package.json
│   └── next.config.js
│
├── edge_nextjs/
│   ├── .next/                    # NextJS build output (app router)
│   ├── .nvmrc                    # Node version specification
│   ├── .env.local                # Contentful API keys
│   ├── app/                      # App router directory
│   ├── public/                   # Static assets
│   ├── package.json
│   └── next.config.js
│
└── forge_nextjs/
    ├── .next/                    # NextJS build output (app router)
    ├── .nvmrc                    # Node version specification
    ├── .env.local                # Contentful API keys
    ├── app/                      # App router directory
    ├── public/                   # Static assets
    ├── package.json
    └── next.config.js
```

---

## 🔧 PM2 Configuration

### Cluster Mode for Maximum Performance

Each application runs in **cluster mode** with 2 instances per app (6 total processes):

```bash
# DetoxNearMe (Pages Router) - Port 3000
pm2 start npm --name "detoxnearme" -i 2 -- run start -- -p 3000
pm2 set detoxnearme:cwd /var/www/apps/detoxnearme

# Edge Treatment (App Router) - Port 3001
pm2 start npm --name "edge_nextjs" -i 2 -- run start -- -p 3001
pm2 set edge_nextjs:cwd /var/www/apps/edge_nextjs

# Forge Recovery (App Router) - Port 3002
pm2 start npm --name "forge_nextjs" -i 2 -- run start -- -p 3002
pm2 set forge_nextjs:cwd /var/www/apps/forge_nextjs

# Save PM2 configuration
pm2 save

# Enable PM2 startup script
pm2 startup systemd
```

### PM2 Ecosystem File

Create `/var/www/apps/ecosystem.config.js`:

```javascript
module.exports = {
  apps: [
    {
      name: 'detoxnearme',
      cwd: '/var/www/apps/detoxnearme',
      script: 'npm',
      args: 'run start -- -p 3000',
      instances: 2,
      exec_mode: 'cluster',
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      error_file: '/var/log/pm2/detoxnearme-error.log',
      out_file: '/var/log/pm2/detoxnearme-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    },
    {
      name: 'edge_nextjs',
      cwd: '/var/www/apps/edge_nextjs',
      script: 'npm',
      args: 'run start -- -p 3001',
      instances: 2,
      exec_mode: 'cluster',
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      error_file: '/var/log/pm2/edge-error.log',
      out_file: '/var/log/pm2/edge-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    },
    {
      name: 'forge_nextjs',
      cwd: '/var/www/apps/forge_nextjs',
      script: 'npm',
      args: 'run start -- -p 3002',
      instances: 2,
      exec_mode: 'cluster',
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 3002
      },
      error_file: '/var/log/pm2/forge-error.log',
      out_file: '/var/log/pm2/forge-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    }
  ]
};
```

**Deploy with ecosystem file:**

```bash
cd /var/www/apps
pm2 start ecosystem.config.js
pm2 save
```

---

## 🌐 NGINX Configuration

### Global Optimization

NGINX is already optimized by `scripts/services.sh nextjs-nginx` with:

- **16,384 worker connections** (high concurrency)
- **Auto worker processes** (matches CPU cores)
- **Gzip compression** (level 6)
- **TLS 1.2/1.3** with strong ciphers
- **Cloudflare real IP** detection
- **Rate limiting** (30 connections/IP)

### Site Configurations

#### 1. DetoxNearMe (Pages Router)

**File**: `/etc/nginx/sites-available/detoxnearme`

```nginx
# Upstream with keepalive connections
upstream detoxnearme {
    server 127.0.0.1:3000;
    keepalive 64;
}

# HTTP → HTTPS redirect (root domain)
server {
    listen 80;
    listen [::]:80;
    server_name detoxnearme.com;

    location / {
        return 301 https://www.$server_name$request_uri;
    }
}

# HTTP → HTTPS redirect (www domain)
server {
    listen 80;
    listen [::]:80;
    server_name www.detoxnearme.com;

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS → HTTPS redirect (root → www)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name detoxnearme.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin-fullchain.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert.key;

    location / {
        return 301 https://www.$server_name$request_uri;
    }
}

# Main HTTPS application server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.detoxnearme.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin-fullchain.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert.key;

    # SSL optimizations
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Static files
    root /var/www/apps/detoxnearme/public;

    # Try static files first, then proxy to Node
    location / {
        try_files $uri @nextjs;
    }

    # NextJS _next static assets (immutable, long cache)
    location /_next/static/ {
        alias /var/www/apps/detoxnearme/.next/static/;
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    # Proxy to NextJS application
    location @nextjs {
        proxy_pass http://detoxnearme;
        proxy_http_version 1.1;

        # Headers
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### 2. Edge Treatment (App Router)

**File**: `/etc/nginx/sites-available/edge_nextjs`

```nginx
# Upstream with keepalive connections
upstream edge_nextjs {
    server 127.0.0.1:3001;
    keepalive 64;
}

# HTTP → HTTPS redirect (root domain)
server {
    listen 80;
    listen [::]:80;
    server_name theedgetreatment.com;

    location / {
        return 301 https://www.$server_name$request_uri;
    }
}

# HTTP → HTTPS redirect (www domain)
server {
    listen 80;
    listen [::]:80;
    server_name www.theedgetreatment.com;

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS → HTTPS redirect (root → www)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name theedgetreatment.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin-fullchain.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert.key;

    location / {
        return 301 https://www.$server_name$request_uri;
    }
}

# Main HTTPS application server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.theedgetreatment.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin-fullchain.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert.key;

    # SSL optimizations
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Static files
    root /var/www/apps/edge_nextjs/public;

    # Try static files first, then proxy to Node
    location / {
        try_files $uri @nextjs;
    }

    # NextJS _next static assets (immutable, long cache)
    location /_next/static/ {
        alias /var/www/apps/edge_nextjs/.next/static/;
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    # Proxy to NextJS application
    location @nextjs {
        proxy_pass http://edge_nextjs;
        proxy_http_version 1.1;

        # Headers
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (for HMR in dev)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### 3. Forge Recovery (App Router)

**File**: `/etc/nginx/sites-available/forge_nextjs`

```nginx
# Upstream with keepalive connections
upstream forge_nextjs {
    server 127.0.0.1:3002;
    keepalive 64;
}

# HTTP → HTTPS redirect (root domain)
server {
    listen 80;
    listen [::]:80;
    server_name theforgerecovery.com;

    location / {
        return 301 https://www.$server_name$request_uri;
    }
}

# HTTP → HTTPS redirect (www domain)
server {
    listen 80;
    listen [::]:80;
    server_name www.theforgerecovery.com;

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS → HTTPS redirect (root → www)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name theforgerecovery.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin-fullchain.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert.key;

    location / {
        return 301 https://www.$server_name$request_uri;
    }
}

# Main HTTPS application server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.theforgerecovery.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin-fullchain.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert.key;

    # SSL optimizations
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Static files
    root /var/www/apps/forge_nextjs/public;

    # Try static files first, then proxy to Node
    location / {
        try_files $uri @nextjs;
    }

    # NextJS _next static assets (immutable, long cache)
    location /_next/static/ {
        alias /var/www/apps/forge_nextjs/.next/static/;
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    # Proxy to NextJS application
    location @nextjs {
        proxy_pass http://forge_nextjs;
        proxy_http_version 1.1;

        # Headers
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### Enable NGINX Sites

```bash
# Create symbolic links
ln -sf /etc/nginx/sites-available/detoxnearme /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/edge_nextjs /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/forge_nextjs /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Reload NGINX
systemctl reload nginx
```

---

## 🔐 SSL Certificate Setup

### Cloudflare Origin Certificates

All three sites use **Cloudflare Origin Certificates** for end-to-end encryption:

```bash
# Install SSL certificates
sudo ./scripts/services.sh nextjs-ssl

# Certificates should be placed at:
# /etc/ssl/certs/cloudflare-origin-fullchain.pem
# /etc/ssl/private/ssl-cert.key (600 permissions)
```

### Certificate Validation

```bash
# Verify certificate
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -text -noout

# Check expiration
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -noout -dates
```

---

## 📊 Resource Monitoring

### PM2 Monitoring

```bash
# View all processes
pm2 list

# Monitor in real-time
pm2 monit

# View logs
pm2 logs

# View specific app logs
pm2 logs detoxnearme
pm2 logs edge_nextjs
pm2 logs forge_nextjs

# Resource usage
pm2 describe detoxnearme
pm2 describe edge_nextjs
pm2 describe forge_nextjs
```

### System Monitoring

```bash
# CPU and memory usage
htop

# NGINX connections
watch -n 1 "netstat -tn | grep :80 | wc -l"
watch -n 1 "netstat -tn | grep :443 | wc -l"

# Disk usage
df -h

# Application ports
ss -tlnp | grep -E ':(3000|3001|3002)'
```

---

## 🧪 Testing & Validation

### Application Health Checks

```bash
# Test local endpoints
curl -I http://localhost:3000  # DetoxNearMe
curl -I http://localhost:3001  # Edge Treatment
curl -I http://localhost:3002  # Forge Recovery

# Test HTTPS endpoints
curl -I https://www.detoxnearme.com
curl -I https://www.theedgetreatment.com
curl -I https://www.theforgerecovery.com

# Test redirects (should return 301)
curl -I http://detoxnearme.com
curl -I https://detoxnearme.com  # Should redirect to www
```

### Performance Testing

```bash
# Apache Bench - 1000 requests, 10 concurrent
ab -n 1000 -c 10 https://www.detoxnearme.com/
ab -n 1000 -c 10 https://www.theedgetreatment.com/
ab -n 1000 -c 10 https://www.theforgerecovery.com/

# Check response times
time curl -s https://www.detoxnearme.com/ > /dev/null
```

---

## 🔄 Deployment Workflow

### Manual Deployment Steps

```bash
# 1. Pull latest code from source
cd /var/www/apps/detoxnearme
git pull origin main

# 2. Install dependencies
npm ci --production

# 3. Build application
npm run build

# 4. Restart PM2 process
pm2 restart detoxnearme

# 5. Verify deployment
pm2 logs detoxnearme --lines 50
curl -I http://localhost:3000
```

### Automated Deployment

```bash
# Use the deployment script
sudo ./scripts/services.sh deploy-detoxnearme
sudo ./scripts/services.sh deploy-edge
sudo ./scripts/services.sh deploy-forge

# Or deploy all at once
sudo ./scripts/services.sh deploy-node-steelgem
```

---

## 🛡️ Security Considerations

### Firewall Rules

```bash
# Allow HTTP/HTTPS traffic
ufw allow 80/tcp
ufw allow 443/tcp

# Application ports should NOT be exposed directly
# (Only accessible via NGINX reverse proxy)

# Verify firewall status
ufw status verbose
```

### Environment Variables

**NEVER commit `.env.local` files to version control!**

```bash
# DetoxNearMe environment variables
/var/www/apps/detoxnearme/.env.local
DATABASE_URL="postgresql://user:pass@sql-steelgem:5432/detoxnearme"
NEXT_PUBLIC_API_URL="https://cms.detoxnearme.com"

# Edge Treatment environment variables
/var/www/apps/edge_nextjs/.env.local
CONTENTFUL_SPACE_ID="xxx"
CONTENTFUL_ACCESS_TOKEN="xxx"
CONTENTFUL_PREVIEW_ACCESS_TOKEN="xxx"

# Forge Recovery environment variables
/var/www/apps/forge_nextjs/.env.local
CONTENTFUL_SPACE_ID="yyy"
CONTENTFUL_ACCESS_TOKEN="yyy"
CONTENTFUL_PREVIEW_ACCESS_TOKEN="yyy"
```

---

## 📈 Performance Optimization

### NextJS Build Optimizations

**next.config.js settings for production:**

```javascript
module.exports = {
  compress: true,
  poweredByHeader: false,
  generateEtags: true,

  // App Router specific (Edge + Forge)
  experimental: {
    optimizePackageImports: ['lodash', 'date-fns']
  },

  // Image optimization
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384]
  },

  // Static page generation
  output: 'standalone'  // For containerized deployments
};
```

### NGINX Caching Strategy

**Add to NGINX configuration:**

```nginx
# Cache static assets
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    access_log off;
}

# Cache HTML for 1 hour (with revalidation)
location ~* \.html$ {
    expires 1h;
    add_header Cache-Control "public, must-revalidate";
}
```

---

## 🐛 Troubleshooting

### Common Issues

#### PM2 Process Not Starting

```bash
# Check logs for errors
pm2 logs detoxnearme --err --lines 100

# Delete and recreate process
pm2 delete detoxnearme
pm2 start npm --name "detoxnearme" -i 2 -- run start -- -p 3000

# Verify Node version
node --version
cat /var/www/apps/detoxnearme/.nvmrc
```

#### NGINX 502 Bad Gateway

```bash
# Check if Node process is running
pm2 list
ss -tlnp | grep 3000

# Check NGINX error logs
tail -f /var/log/nginx/error.log

# Restart services
pm2 restart all
systemctl restart nginx
```

#### High Memory Usage

```bash
# Check PM2 memory limits
pm2 describe detoxnearme | grep memory

# Restart high-memory processes
pm2 restart detoxnearme

# Adjust max_memory_restart in ecosystem.config.js
```

#### Port Already in Use

```bash
# Find process using port
lsof -i :3000

# Kill process
kill -9 <PID>

# Or stop PM2 process
pm2 stop detoxnearme
```

---

## 📝 Maintenance Tasks

### Daily

- [ ] Check PM2 process status: `pm2 list`
- [ ] Monitor error logs: `pm2 logs --err --lines 50`
- [ ] Verify HTTPS certificates are valid

### Weekly

- [ ] Review resource usage: `pm2 monit`
- [ ] Check disk space: `df -h`
- [ ] Review NGINX access logs: `tail -1000 /var/log/nginx/access.log`
- [ ] Update dependencies: `npm audit`

### Monthly

- [ ] System updates: `apt update && apt upgrade`
- [ ] Review PM2 logs and clean old logs
- [ ] Performance testing with `ab` or similar tools
- [ ] Backup configurations and ecosystem files

---

## 🔗 Related Documentation

- [NEXTJS-DEPLOYMENT.md](./NEXTJS-DEPLOYMENT.md) - Detailed NextJS deployment functions
- [NEXTJS-QUICKSTART.md](./NEXTJS-QUICKSTART.md) - Quick start examples
- [SERVER-CONTEXT.md](./SERVER-CONTEXT.md) - Server architecture overview
- [DYNAMIC-SSH-GUIDE.md](./DYNAMIC-SSH-GUIDE.md) - SSH configuration

---

## 📞 Support & Contact

For issues or questions:

1. Check troubleshooting section above
2. Review PM2 logs: `pm2 logs`
3. Check NGINX logs: `/var/log/nginx/error.log`
4. Verify firewall rules: `ufw status verbose`

---

**Last Updated**: February 7, 2026
**Maintained By**: DevOps Team
**Server**: node-steelgem (Ubuntu 24.04 LTS)
