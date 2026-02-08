# DetoxNearMe Deployment - Configuration Summary

**Deployment Date**: February 8, 2026
**Server**: node-steelgem
**Application**: detoxnearme.com
**Status**: ✅ Production - Live and Working

---

## ✅ Deployment Verification

### Application Status

```
PM2 Process: detoxnearme
Mode: fork (single instance)
Status: online
Uptime: Running
Node Version: 22.9.0
Port: 3001
Memory: ~65MB
```

### URLs Working

- ✅ <https://detoxnearme.com> (Primary)
- ✅ <http://detoxnearme.com> → redirects to HTTPS
- ✅ <https://www.detoxnearme.com> → redirects to root domain
- ✅ <http://localhost:3001> (Application)

---

## 📋 Configuration Details

### Node.js Configuration

- **Node Version**: 22.9.0 (from .nvmrc)
- **Source**: `/home/ubuntu/detoxnearme.com/gitlab/.nvmrc`
- **NVM Path**: `/root/.nvm/versions/node/v22.9.0`
- **Why 22.9.0**: Required by dependencies (TypeScript ESLint plugins need `^20.9.0 || >=21.1.0`)

### Application Configuration

- **Framework**: NextJS 13.5.6 (Pages Router)
- **Directory**: `/home/ubuntu/detoxnearme.com/gitlab/`
- **Port**: 3001 (set via PORT environment variable)
- **Environment File**: `.env.local` (chmod 600)
- **Build Directory**: `.next/`

### PM2 Configuration

- **Process Name**: detoxnearme
- **Mode**: fork (single instance, NOT cluster)
- **Start Command**: `PORT=3001 pm2 start npm --name detoxnearme -- run start`
- **Working Directory**: `/home/ubuntu/detoxnearme.com/gitlab`
- **Node Version**: 22.9.0 (via NVM)
- **Logs**: `/root/.pm2/logs/detoxnearme-*.log`
- **Auto-Restart**: Enabled
- **Startup**: Saved in PM2 dump.pm2

### SSL Configuration

**Critical**: Using certificates provided in `conf/node-steelgem/detoxnearme/nginx/`

- **Certificate**: `/etc/ssl/detoxnearme/cert.pem` (chmod 644)
- **Private Key**: `/etc/ssl/detoxnearme/key.pem` (chmod 600)
- **Source**: `conf/node-steelgem/detoxnearme/nginx/cert.pem` and `key.pem`
- **Type**: Self-signed certificate (behind Cloudflare)
- **Note**: OCSP stapling disabled (no intermediate certificate)

### NGINX Configuration

- **Global Config**: `/etc/nginx/nginx.conf`
- **Site Config**: `/etc/nginx/sites-available/detoxnearme.com.conf`
- **Symlink**: `/etc/nginx/sites-enabled/detoxnearme.com.conf`
- **Upstream**: `detoxnearme` on `127.0.0.1:3001`
- **HTTP/2**: Enabled
- **SSL**: Configured with provided certificates
- **Redirects**:
  - HTTP → HTTPS
  - www subdomain → root domain

---

## 🔧 Management Commands

### PM2 Commands

```bash
# View status
pm2 list

# View logs
pm2 logs detoxnearme

# Restart application
pm2 restart detoxnearme

# Stop application
pm2 stop detoxnearme

# View detailed info
pm2 describe detoxnearme
```

### NGINX Commands

```bash
# Test configuration
sudo nginx -t

# Reload NGINX
sudo systemctl reload nginx

# Check status
sudo systemctl status nginx

# View error logs
sudo tail -f /var/log/nginx/error.log
```

### Application Commands

```bash
# Test local application
curl -I http://localhost:3001

# Test through NGINX
curl -I https://detoxnearme.com

# Check Node version
node --version

# Switch Node version
nvm use 22.9.0
```

---

## 📂 File Locations

### Application Files

```
/home/ubuntu/detoxnearme.com/gitlab/
├── .env.local              # Environment variables (chmod 600)
├── .nvmrc                  # Node version: 22.9.0
├── .next/                  # Built application
├── pages/                  # NextJS pages
├── public/                 # Static assets
├── package.json            # Dependencies
└── next.config.js          # NextJS configuration
```

### SSL Certificates

```
/etc/ssl/detoxnearme/
├── cert.pem               # SSL certificate (chmod 644)
└── key.pem                # Private key (chmod 600)
```

### NGINX Configuration

```
/etc/nginx/
├── nginx.conf                                    # Global config
├── sites-available/detoxnearme.com.conf         # Site config
└── sites-enabled/detoxnearme.com.conf           # Symlink
```

### PM2 Files

```
/root/.pm2/
├── logs/
│   ├── detoxnearme-error.log
│   └── detoxnearme-out.log
├── pids/detoxnearme-4.pid
└── dump.pm2                # Saved configuration
```

---

## 🔐 Security Configuration

### SSL/TLS

- **Protocols**: TLSv1.2, TLSv1.3
- **Ciphers**: HIGH:!aNULL:!MD5
- **Session Cache**: 10m
- **HSTS**: Enabled (via Cloudflare)

### File Permissions

```bash
# Environment file
chmod 600 /home/ubuntu/detoxnearme.com/gitlab/.env.local
chown ubuntu:ubuntu /home/ubuntu/detoxnearme.com/gitlab/.env.local

# SSL certificates
chmod 644 /etc/ssl/detoxnearme/cert.pem
chmod 600 /etc/ssl/detoxnearme/key.pem
chown root:root /etc/ssl/detoxnearme/*.pem
```

---

## 🚀 Deployment Process (Reproducible)

### 1. Upload Application Code

```bash
# Extract archive on server
cd /home/ubuntu/detoxnearme.com/gitlab
sudo tar -xzf archive.tar.gz
sudo chown -R ubuntu:ubuntu .
```

### 2. Install Correct Node Version

```bash
# Create .nvmrc
echo '22.9.0' > .nvmrc

# Install Node 22.9.0
sudo bash -l -c 'source /root/.nvm/nvm.sh && nvm install 22.9.0 && nvm alias default 22.9.0'
```

### 3. Install Dependencies

```bash
cd /home/ubuntu/detoxnearme.com/gitlab
sudo bash -l -c 'source /root/.nvm/nvm.sh && nvm use 22.9.0 && npm install --production --ignore-scripts'
```

### 4. Deploy SSL Certificates

```bash
# From local machine
scp conf/node-steelgem/detoxnearme/nginx/cert.pem node-steelgem:/tmp/
scp conf/node-steelgem/detoxnearme/nginx/key.pem node-steelgem:/tmp/

# On server
sudo mkdir -p /etc/ssl/detoxnearme
sudo mv /tmp/cert.pem /etc/ssl/detoxnearme/cert.pem
sudo mv /tmp/key.pem /etc/ssl/detoxnearme/key.pem
sudo chmod 644 /etc/ssl/detoxnearme/cert.pem
sudo chmod 600 /etc/ssl/detoxnearme/key.pem
```

### 5. Deploy NGINX Configuration

```bash
# From local machine
scp conf/node-steelgem/detoxnearme/nginx/nginx.conf node-steelgem:/tmp/
scp conf/node-steelgem/detoxnearme/nginx/detoxnearme.com.conf node-steelgem:/tmp/

# On server
sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf
sudo mv /tmp/detoxnearme.com.conf /etc/nginx/sites-available/detoxnearme.com.conf
sudo ln -sf /etc/nginx/sites-available/detoxnearme.com.conf /etc/nginx/sites-enabled/detoxnearme.com.conf
sudo nginx -t
sudo systemctl reload nginx
```

### 6. Configure Environment

```bash
# Add PORT to .env.local
echo 'PORT=3001' >> /home/ubuntu/detoxnearme.com/gitlab/.env.local
chmod 600 /home/ubuntu/detoxnearme.com/gitlab/.env.local
```

### 7. Start PM2 Process

```bash
cd /home/ubuntu/detoxnearme.com/gitlab
sudo bash -l -c 'source /root/.nvm/nvm.sh && nvm use 22.9.0 && PORT=3001 pm2 start npm --name detoxnearme -- run start'
pm2 save
```

### 8. Verify Deployment

```bash
# Check PM2 status
pm2 list
pm2 logs detoxnearme --lines 20

# Test local application
curl -I http://localhost:3001

# Test through NGINX
curl -I https://detoxnearme.com
```

---

## 📊 Performance Metrics

### Current Metrics (at deployment)

- **Memory Usage**: ~65MB
- **CPU Usage**: <1%
- **Startup Time**: ~440ms
- **Process Restarts**: 0
- **Uptime**: Running

### Expected Performance

- **Response Time**: <200ms
- **Memory**: 50-100MB (normal)
- **CPU**: <5% (under normal load)

---

## 🔍 Troubleshooting

### Application Won't Start

```bash
# Check Node version
node --version
cat .nvmrc

# Reinstall dependencies
cd /home/ubuntu/detoxnearme.com/gitlab
rm -rf node_modules
npm install --production --ignore-scripts

# Check port availability
lsof -i :3001
```

### SSL Certificate Issues

```bash
# Verify certificates exist
ls -la /etc/ssl/detoxnearme/

# Check permissions
ls -la /etc/ssl/detoxnearme/*.pem

# Verify certificate matches key
openssl x509 -noout -modulus -in /etc/ssl/detoxnearme/cert.pem | openssl md5
openssl rsa -noout -modulus -in /etc/ssl/detoxnearme/key.pem | openssl md5
```

### NGINX Issues

```bash
# Test configuration
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log

# Verify upstream is running
curl -I http://localhost:3001
```

---

## ⚠️ Important Notes

### SSL Certificates

**CRITICAL**: Always use the SSL certificates provided in `conf/node-steelgem/detoxnearme/nginx/`. Do NOT substitute with Cloudflare origin certificates or other random certificates found on the server.

### Node Version

**CRITICAL**: Always use Node version from `.nvmrc`. The application requires 22.9.0 to satisfy dependency requirements.

### Port Configuration

The application runs on port **3001** (not 3000) because edge_nextjs is already using port 3000.

---

## 📚 Related Documentation

- [PM2-GUIDE.md](PM2-GUIDE.md) - Detailed PM2 management guide
- [nginx/detoxnearme.com.conf](nginx/detoxnearme.com.conf) - NGINX site configuration
- [nginx/nginx.conf](nginx/nginx.conf) - Global NGINX configuration
- [DEPLOYMENT-STANDARDS.md](../../../docs/DEPLOYMENT-STANDARDS.md) - Deployment standards and best practices

---

**Deployment Completed Successfully**: February 8, 2026 07:49 UTC
**Verified By**: Deployment automation
**Status**: ✅ Production Ready
