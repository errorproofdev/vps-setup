# NextJS Migration & Deployment Guide

This document describes the automated NextJS deployment functions in `scripts/services.sh` for migrating NextJS applications from EC2 to the VPS.

## Functions to Implement

### 1. NVM Management Functions

#### `install_nvm()`

- Installs Node Version Manager (NVM) v0.39.0
- Sets up NVM environment sourcing in `~/.nvm/nvm.sh`
- Enables per-application Node.js version management via `.nvmrc`

**Usage:**

```bash
./scripts/services.sh nvm
```

#### `load_nvm_and_node(app_path)`

- Reads `.nvmrc` from application directory
- Installs the specified Node.js version
- Activates it for the current shell session
- Falls back to system Node.js if no `.nvmrc` found

**Usage:**

```bash
load_nvm_and_node "/var/www/apps/edge_nextjs"
```

### 2. NGINX Configuration Functions

#### `optimize_nginx_global()`

- Replaces global `nginx.conf` with production-optimized settings
- Configures:
  - Worker processes: `auto` (scales with CPU cores)
  - Connections per worker: `16384`
  - Timeouts: 60 seconds (client, proxy, send)
  - Gzip compression: Level 6
  - SSL: TLSv1.2/1.3, strong ciphers
  - Security headers: HSTS, X-Content-Type-Options, X-Frame-Options
  - Cloudflare real IP ranges: IPv4 + IPv6 (30 ranges)
  - Rate limiting: 30 connections per IP
- Creates backup: `nginx.conf.backup`
- Validates configuration before reload

**Usage:**

```bash
./scripts/services.sh nextjs-nginx
```

#### `install_cloudflare_ssl_certs()`

- Copies Cloudflare origin SSL certificates from `conf/` folder
- Destination: `/etc/ssl/certs/cloudflare-origin-fullchain.pem`
- Private key: `/etc/ssl/private/ssl-cert.key` (600 permissions)
- Validates certificates with `openssl x509`

**Configuration:**

- Default source: `./conf/www.theedgetreatment.com/ssl/`
- Can override with `CERT_SOURCE` and `KEY_SOURCE` environment variables

**Usage:**

```bash
./scripts/services.sh nextjs-ssl
```

#### `create_nginx_nextjs_site(domain, port, app_name, [ssl_cert], [ssl_key])`

- Generates NGINX site configuration for NextJS application
- Creates upstream block with keepalive: 64
- Four server blocks:
  1. HTTP → HTTPS redirect (root domain)
  2. HTTP → HTTPS redirect (www domain)
  3. HTTPS → HTTPS redirect (root→www)
  4. HTTPS application server (www domain only)
- Enables proxy headers, WebSocket support, static asset caching
- Validates configuration before reload

**Output file:** `/etc/nginx/sites-available/{app_name}`
**Symlink:** `/etc/nginx/sites-enabled/{app_name}`

**Usage:**

```bash
create_nginx_nextjs_site "theedgetreatment.com" 3000 "edge_nextjs"
```

### 3. Application Deployment Functions

#### `deploy_nextjs_app(app_name, domain, port, [ssh_host], [remote_path])`

**12-step deployment process:**

1. Create local app directory: `/var/www/apps/{app_name}`
2. Transfer app files from EC2 via rsync
   - Excludes: `node_modules`, `.git`, `.next`, `dist`
   - Uses ssh_host alias (default: `edge-prod`)
   - Remote path (default: `/home/ubuntu/current`)
3. Transfer `.env.local` via scp
   - Permissions: 600 (readable by www-data only)
4. Set directory ownership to `www-data:www-data`
5. Load NVM and activate Node.js version from `.nvmrc`
6. Install production dependencies: `npm ci --production`
7. Build NextJS app: `NODE_ENV=production npm run build`
   - Verifies `.next` directory exists
8. Create PM2 ecosystem config
   - Process name: app_name (e.g., "edge_nextjs")
   - Start command: `npm start -- -p {port}`
   - Fork mode (single instance)
   - Auto-restart, max 1GB memory
   - Logs: `/var/log/pm2/{app_name}-{error,out}.log`
9. Create PM2 log directory with www-data ownership
10. Start app with PM2: `pm2 start ecosystem.config.js`
    - Save PM2 state for respawn on reboot
11. Create NGINX site config for domain
12. Test connectivity: `curl http://localhost:{port}`

**Defaults:**

- ssh_host: "edge-prod" (SSH config alias)
- remote_path: "/home/ubuntu/current" (EC2 app directory)

**Usage:**

```bash
# Deploy edge_nextjs (all defaults)
deploy_nextjs_app "edge_nextjs" "theedgetreatment.com" 3000 "edge-prod" "/home/ubuntu/current"

# Deploy custom app
deploy_nextjs_app "my_app" "mydomain.com" 3001 "prod-server" "/opt/myapp"
```

**Environment Variables:**
The function preserves all variables from `.env.local`, including:

- API keys and tokens
- Database credentials
- Third-party service configs
- Redis/cache connections

#### `test_nextjs_deployment(app_name, port, [domain])`

**5-test deployment validation:**

1. PM2 process status check
   - Verifies process is online
2. Port connectivity test
   - `curl http://localhost:{port}`
3. NGINX configuration validation
   - `nginx -t`
4. Memory usage check
   - Retrieves current memory from PM2
5. Error log inspection
   - Searches last 5 lines of PM2 error log

**Usage:**

```bash
test_nextjs_deployment "edge_nextjs" 3000
```

### 4. Migration Orchestration Functions

#### `migrate_edge_treatment()`

**Wrapper function for <www.theedgetreatment.com> migration**

**Pre-flight checks:**

- Disk space: Requires at least 10GB in `/var/www`
- NVM: Installs if not found
- NGINX: Starts if not running
- PM2: Installs globally if missing
- SSL certs: Installs if missing

**Deployment steps:**

1. Run pre-flight checks
2. Call `deploy_nextjs_app("edge_nextjs", "theedgetreatment.com", 3000, "edge-prod", "/home/ubuntu/current")`
3. Run post-deployment tests

**Usage:**

```bash
./scripts/services.sh edge-migrate
```

## CLI Integration

### New Service Commands

These are available in `scripts/services.sh` (show_services + case statement):

```bash
nvm                # Install NVM for Node version management
nextjs-nginx        # Optimize NGINX global configuration
nextjs-ssl          # Install Cloudflare origin SSL certificates
edge-migrate       # Full migration for www.theedgetreatment.com
nextjs-deploy      # Deploy custom NextJS app (requires params)
nextjs-test        # Test NextJS deployment (requires params)
```

### Usage Examples

```bash
# Initialize NVM
sudo ./scripts/services.sh nvm

# Optimize NGINX (run once on VPS)
sudo ./scripts/services.sh nextjs-nginx

# Install SSL certificates
sudo ./scripts/services.sh nextjs-ssl

# Full migration for Edge Treatment
sudo ./scripts/services.sh edge-migrate

# Deploy custom app
sudo ./scripts/services.sh nextjs-deploy "forge_nextjs" "theforgerecovery.com" 3001

# Test deployment
sudo ./scripts/services.sh nextjs-test "edge_nextjs" 3000
```

## Migration Timeline

### Phase 1: Preparation (VPS Setup)

- [ ] Run `sudo ./scripts/vps-setup.sh` (base system)
- [ ] Run `sudo ./scripts/services.sh postgresql` (if needed)
- [ ] Run `sudo ./scripts/services.sh redis` (if needed)
- [ ] Copy SSL certificates to `conf/www.theedgetreatment.com/ssl/`
- [ ] Verify NextJS functions in `scripts/services.sh`

### Phase 2: First App Migration (Edge Treatment)

- [ ] Run `sudo ./scripts/services.sh nvm`
- [ ] Run `sudo ./scripts/services.sh nextjs-nginx`
- [ ] Run `sudo ./scripts/services.sh nextjs-ssl`
- [ ] Run `sudo ./scripts/services.sh edge-migrate`
- [ ] Verify: `pm2 list` shows `edge_nextjs` online
- [ ] Verify: `curl https://www.theedgetreatment.com`
- [ ] Monitor logs: `pm2 logs edge_nextjs`

### Phase 3: Subsequent Apps (The Forge, DetoxNearMe)

- [ ] Deploy The Forge: `sudo ./scripts/services.sh nextjs-deploy "forge_nextjs" "theforgerecovery.com" 3001`
- [ ] Deploy DetoxNearMe: `sudo ./scripts/services.sh nextjs-deploy "detoxnearme" "detoxnearme.com" 3002`
- [ ] Run tests and verify each deployment

### Phase 4: DNS & Cutover

- [ ] Update Cloudflare DNS A records to point to VPS IP
- [ ] Verify HTTPS certificates are valid
- [ ] Monitor application logs for errors
- [ ] Keep EC2 running as fallback for 24 hours
- [ ] Decommission EC2 after verification period

## Troubleshooting

### Common Issues

**App won't build:**

```bash
# Check Node version
node --version

# Check build errors
pm2 logs edge_nextjs --err

# Manual build test
cd /var/www/apps/edge_nextjs
npm run build
```

**Port not responding:**

```bash
# Check NGINX is proxying correctly
nginx -t

# Check PM2 status
pm2 status
pm2 logs edge_nextjs

# Test directly
curl http://localhost:3000
```

**NGINX config issues:**

```bash
# Validate configuration
nginx -t

# Check syntax errors
grep -n "error" /etc/nginx/sites-available/edge_nextjs

# Reload with fresh config
systemctl reload nginx
```

**SSL certificate issues:**

```bash
# Verify certificate validity
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -text -noout

# Check certificate dates
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -noout -dates
```

**PM2 process respawn issues:**

```bash
# Check PM2 restart logs
pm2 log edge_nextjs

# Verify ecosystem config
cat /var/www/apps/edge_nextjs/ecosystem.config.js

# Manual PM2 restart
pm2 restart edge_nextjs
```

## Architecture Details

### Directory Structure

```
/var/www/apps/
├── edge_nextjs/              # App directory
│   ├── .next/                # Next.js build output
│   ├── node_modules/         # Dependencies
│   ├── public/               # Static assets
│   ├── src/                  # Source code
│   ├── .env.local            # Environment variables (600 perms)
│   ├── .nvmrc               # Node version (e.g., "18.19.0")
│   ├── ecosystem.config.js  # PM2 configuration
│   ├── package.json
│   ├── package-lock.json
│   └── ...

/etc/nginx/
├── sites-available/
│   ├── edge_nextjs           # Generated site config
│   └── ...
├── sites-enabled/
│   └── edge_nextjs -> ../sites-available/edge_nextjs
└── nginx.conf               # Optimized global config

/var/log/pm2/
├── edge_nextjs-error.log
└── edge_nextjs-out.log

/etc/ssl/
├── certs/
│   └── cloudflare-origin-fullchain.pem
└── private/
    └── ssl-cert.key

~/.nvm/
├── versions/node/
│   ├── v18.19.0/
│   ├── v20.10.0/
│   └── ...
└── nvm.sh
```

### Network Flow

```
Client Request
    ↓
Cloudflare DNS (A record → VPS IP)
    ↓
VPS NGINX (Port 443, TLS termination)
    ↓
Upstream edge_nextjs (127.0.0.1:3000)
    ↓
PM2 fork process (npm start -- -p 3000)
    ↓
Node.js Next.js application
```

### File Permissions

```
/var/www/apps/edge_nextjs/          755 (www-data:www-data)
/var/www/apps/edge_nextjs/.env.local 600 (www-data:www-data)
/etc/ssl/private/ssl-cert.key        600 (root:root)
/etc/ssl/certs/cloudflare-*.pem      644 (root:root)
/var/log/pm2/                        755 (www-data:www-data)
```

## Performance Considerations

### NGINX Optimization

- Worker processes: `auto` (scales to CPU count)
- Keepalive connections: 64 per upstream
- Gzip compression: Level 6 (balance speed/ratio)
- SSL session caching: 10MB shared cache
- Proxy buffering: 16x 32KB buffers

### Node.js/NextJS Settings

- Fork mode: Single process per app
- Memory limit: 1GB max restart threshold
- Max uptime: 10 seconds min before respawn
- Auto-restart: Up to 10 restarts
- Production environment: NODE_ENV=production

### Database Connections

- PostgreSQL: Separate server (10.0.35.x)
- Redis: Separate server (10.0.35.126:6379)
- Connection pooling: Configure in app .env

## Security Considerations

1. **SSL/TLS:**
   - Cloudflare origin certificates (not Let's Encrypt)
   - TLSv1.2 minimum, TLSv1.3 preferred
   - Strong cipher suites (ECDHE, CHACHA20)
   - HSTS max-age: 63072000 (2 years)

2. **File Permissions:**
   - `.env.local`: 600 (readable by www-data only)
   - Private keys: 600 (root:root)
   - Application files: 755 (executable)

3. **Environment Variables:**
   - Transferred via scp (not logged)
   - Stored with restricted permissions
   - No backup/export (re-copy on need)

4. **Network Access:**
   - NGINX reverse proxy (no direct app access)
   - Cloudflare DDoS protection
   - UFW firewall rules

## Related Documentation

- [README.md](../README.md) - Main project documentation
- [scripts/deploy.sh](../scripts/deploy.sh) - Deployment configurations
- [scripts/vps-setup.sh](../scripts/vps-setup.sh) - Base VPS setup script
