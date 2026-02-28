<!-- markdownlint-disable MD022 MD031 MD032 MD046 -->

# NextJS Migration Quick Start

> **Security reminder:** all production Next.js deployments use a hardening
> model with a dedicated non-root `appuser`, localhost-only TCP ports and
> NGINX proxying via Unix sockets. See
> [`docs/SECURE-NON-ROOT-DEPLOYMENT.md`](SECURE-NON-ROOT-DEPLOYMENT.md) for
> full details.

## ✅ What's Been Integrated

Your `scripts/services.sh` now includes **8 new NextJS deployment functions**:

1. **`install_nvm()`** - Installs NVM v0.39.0 for per-app Node version management
2. **`load_nvm_and_node(app_path)`** - Reads `.nvmrc` and activates correct Node version
3. **`optimize_nginx_global()`** - Configures NGINX for NextJS (16,384 connections, Cloudflare IPs, gzip, TLS)
4. **`install_cloudflare_ssl_certs()`** - Installs Cloudflare origin certificates
5. **`create_nginx_nextjs_site(domain, port, app_name, [cert], [key])`** - Generates NGINX site config
6. **`deploy_nextjs_app(app_name, domain, port, [ssh_host], [remote_path])`** - 12-step deployment automation
7. **`test_nextjs_deployment(app_name, port)`** - 5-test validation suite
8. **`migrate_edge_treatment()`** - One-command migration for <www.theedgetreatment.com>

## 📋 VPS Essentials Status

| Essential | Status | Installation |
|-----------|--------|--------------|
| Tailscale | ✅ | `./scripts/services.sh tailscale` |
| NGINX | ✅ | Installed by `scripts/vps-setup.sh` |
| NVM + Node.js LTS | ✅ | `./scripts/services.sh nvm` |
| npm | ✅ | Installed with Node.js LTS |
| PM2 | ✅ | Installed with Node.js LTS |

## 🔑 Using NVM Over SSH

NVM is installed to both `.bashrc` (interactive shells) and `.profile` (login shells). When running NVM commands over SSH from your local machine:

```bash
# Option 1: Source .profile in your command
ssh node-steelgem "source ~/.profile && nvm install node@lts"

# Option 2: Use an interactive shell
ssh -t node-steelgem "bash -i -c 'nvm install node@lts'"

# Option 3: SSH in first, then run commands (recommended for multiple commands)
ssh node-steelgem
nvm --version    # Works in interactive session
node --version
```

**Why is this needed?** Non-interactive SSH sessions don't automatically source `.bashrc`, so NVM isn't in the PATH. Sourcing `.profile` explicitly makes NVM available.

## 🚀 Usage Examples

### Option 1: Fully Automated Migration (Recommended)

```bash
# SSH into your VPS first
sudo ./scripts/services.sh edge-migrate
```

This single command:

- Installs Cloudflare SSL certificates
- Optimizes NGINX for NextJS
- Transfers code from edge-prod:/home/ubuntu/current
- Builds NextJS app
- Starts PM2 process on port 3000
- Creates NGINX config for <www.theedgetreatment.com>
- Runs 5 deployment tests

### Option 2: Manual Step-by-Step

#### Step 1: Install NVM

```bash
sudo ./scripts/services.sh nvm
```

#### Step 2: Optimize NGINX

```bash
sudo ./scripts/services.sh nextjs-nginx
```

#### Step 3: Install Cloudflare SSL

```bash
# Ensure conf/www.theedgetreatment.com/ssl/ contains:
# - cloudflare-origin-fullchain.pem
# - key.pem
sudo ./scripts/services.sh nextjs-ssl
```

#### Step 4: Deploy App

```bash
sudo ./scripts/services.sh nextjs-deploy edge_nextjs theedgetreatment.com 3000 edge-prod /home/ubuntu/current
```

#### Step 5: Test Deployment

```bash
sudo ./scripts/services.sh nextjs-test edge_nextjs 3000
```

### Option 3: Deploy Other Apps

#### The Forge Recovery (forge_nextjs)

```bash
sudo ./scripts/services.sh nextjs-deploy forge_nextjs theforgerecovery.com 3001 forge-prod /home/ubuntu/current
sudo ./scripts/services.sh nextjs-test forge_nextjs 3001
```

#### Detox Near Me (detoxnearme)

```bash
sudo ./scripts/services.sh nextjs-deploy detoxnearme detoxnearme.com 3002 detox-prod /home/ubuntu/current
sudo ./scripts/services.sh nextjs-test detoxnearme 3002
```

## 📂 File Structure Created

```
/var/www/apps/
├── edge_nextjs/              # Port 3000
│   ├── .next/
│   ├── .nvmrc
│   ├── .env.local
│   ├── ecosystem.config.js
│   └── [app files]
├── forge_nextjs/             # Port 3001
└── detoxnearme/              # Port 3002

/etc/nginx/
├── nginx.conf                # Optimized global config
├── nginx.conf.backup         # Original backup
├── sites-available/
│   ├── edge_nextjs
│   ├── forge_nextjs
│   └── detoxnearme
└── sites-enabled/            # Symlinks

/etc/ssl/
├── certs/cloudflare-origin-fullchain.pem
└── private/ssl-cert.key

/var/log/pm2/
├── edge_nextjs-error.log
├── edge_nextjs-out.log
├── forge_nextjs-error.log
└── detoxnearme-out.log
```

## 🔧 Environment Variables

### For SSL Certificate Installation

```bash
export CERT_SOURCE="./conf/www.theedgetreatment.com/ssl/cloudflare-origin-fullchain.pem"
export KEY_SOURCE="./conf/www.theedgetreatment.com/ssl/key.pem"
sudo ./scripts/services.sh nextjs-ssl
```

## 🧪 Testing Commands

### Check PM2 Status

```bash
pm2 status
pm2 logs edge_nextjs --lines 50
pm2 monit
```

### Test Port Connectivity

```bash
curl -I http://localhost:3000
curl -I http://localhost:3001
curl -I http://localhost:3002
```

### Validate NGINX

```bash
nginx -t
systemctl status nginx
tail -f /var/log/nginx/error.log
```

### Check SSL Certificates

```bash
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -text -noout
```

## ⚠️ Prerequisites

### On VPS (Ubuntu 24.04)

1. Run base setup first: `sudo ./scripts/vps-setup.sh`
2. Install NVM + Node.js LTS: `sudo ./scripts/services.sh nvm`
3. Install NGINX: Already done by scripts/vps-setup.sh

### On Local Machine

1. Ensure SSH alias `edge-prod` exists in `~/.ssh/config`:

   ```
   Host edge-prod
       HostName <your-ec2-ip>
       User ubuntu
       IdentityFile ~/.ssh/your-key.pem
   ```

2. Place SSL certificates in:

   ```
   ./conf/www.theedgetreatment.com/ssl/
   ├── cloudflare-origin-fullchain.pem
   └── key.pem
   ```

## 🐛 Troubleshooting

### Issue: NVM not found

```bash
# Re-source NVM
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
```

### Issue: Port already in use

```bash
# Check what's using the port
sudo lsof -i :3000
# Stop PM2 process
pm2 stop edge_nextjs
pm2 delete edge_nextjs
```

### Issue: NGINX config failed

```bash
# Restore backup
sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl reload nginx
```

### Issue: Build fails

```bash
# Check Node version matches .nvmrc
cd /var/www/apps/edge_nextjs
cat .nvmrc  # Should match node --version
# Verify environment variables
cat .env.local
# Try manual build
npm run build
```

## 📊 Monitoring

### PM2 Dashboard

```bash
pm2 monit  # Real-time monitoring
pm2 plus   # PM2 Cloud (optional)
```

### NGINX Stats

```bash
# Enable NGINX status module (optional)
curl http://localhost/nginx_status
```

### System Resources

```bash
htop
df -h
free -m
```

## 🔄 Next Steps

1. **Test Edge Treatment Migration**:

   ```bash
   sudo ./scripts/services.sh edge-migrate
   ```

2. **Verify in Browser**:
   - <https://www.theedgetreatment.com>
   - Check SSL certificate (should show Cloudflare)
   - Test all major pages

3. **Migrate Remaining Apps**:

   ```bash
   # Forge Recovery
   sudo ./scripts/services.sh nextjs-deploy forge_nextjs theforgerecovery.com 3001 forge-prod /home/ubuntu/current

   # Detox Near Me
   sudo ./scripts/services.sh nextjs-deploy detoxnearme detoxnearme.com 3002 detox-prod /home/ubuntu/current
   ```

4. **Set Up PM2 Startup**:

   ```bash
   pm2 startup
   pm2 save
   ```

5. **Configure Backups** (optional):

   ```bash
   sudo ./scripts/services.sh backup
   ```

## 📚 Additional Documentation

- **NEXTJS-DEPLOYMENT.md** - Complete technical reference
- **MIGRATION-CHECKLIST.md** - Detailed step-by-step guide
- **SERVER-CONTEXT.md** - Server roles and SSH context

## 🎯 Key Features

✅ **NVM Integration** - Each app uses its own Node version via .nvmrc
✅ **PM2 Fork Mode** - Single instance per app (not cluster)
✅ **Cloudflare SSL** - Origin certificates (valid 2023-2038)
✅ **NGINX Optimization** - 16,384 connections, gzip level 6, Cloudflare IP forwarding
✅ **Automated Testing** - 5-test validation suite
✅ **Error Handling** - Comprehensive backup and rollback mechanisms
✅ **Production Ready** - Environment variable support, proper file permissions

---

**Need help?** Check existing documentation or review the functions in scripts/services.sh (lines 410-750+).
