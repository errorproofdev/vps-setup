# Node-Steelgem Deployment Configuration

This directory contains PM2 and NGINX configurations for all three NextJS applications hosted on `node-steelgem`.

## Directory Structure

```
conf/node-steelgem/
├── README.md                           # This file
├── ecosystem.config.js                 # PM2 ecosystem configuration
│
├── detoxnearme/
│   ├── .env.local.example             # Environment variables template
│   ├── .nvmrc                         # Node version (v20.19.5)
│   ├── pm2.md                         # PM2 process documentation
│   └── nginx/
│       └── detoxnearme.conf           # NGINX site configuration
│
├── edge-nextjs/
│   ├── .env.local.example             # Contentful environment variables template
│   ├── .nvmrc                         # Node version (v20.19.5)
│   ├── pm2.md                         # PM2 process documentation
│   └── nginx/
│       └── theedgetreatment.com.conf  # NGINX site configuration
│
└── forge-nextjs/
    ├── .env.local.example             # Contentful environment variables template
    ├── .nvmrc                         # Node version (v20.19.5)
    ├── pm2.md                         # PM2 process documentation
    └── nginx/
        └── theforgerecovery.com.conf  # NGINX site configuration
```

## Quick Deployment

### All Applications at Once

```bash
# From local machine (bastion)
scp -r conf/node-steelgem/ root@node-steelgem:/tmp/

# SSH and deploy
ssh root@node-steelgem
cd /root/vps-setup
./scripts/services.sh deploy-node-steelgem
```

### Individual Application Deployment

```bash
# DetoxNearMe only
./scripts/services.sh deploy-detoxnearme

# Edge Treatment only
./scripts/services.sh deploy-edge

# Forge Recovery only
./scripts/services.sh deploy-forge
```

## Configuration Files

### Ecosystem Configuration

The `ecosystem.config.js` file defines all three applications with optimal PM2 settings:

- **Cluster mode**: 2 instances per application (6 total)
- **Memory limits**: 1GB per instance with automatic restart
- **Logging**: Centralized to `/var/log/pm2/`
- **Environment**: Production with NODE_ENV set

### NGINX Configurations

Each application has a dedicated NGINX configuration:

- **SSL/TLS**: Cloudflare origin certificates
- **HTTP → HTTPS redirects**: Automatic
- **Root → www redirects**: Automatic (SEO best practice)
- **Static asset caching**: 365 days for immutable assets
- **WebSocket support**: Enabled for Next.js HMR
- **Keepalive connections**: 64 connections per upstream

### Environment Variables

Each application requires specific environment variables:

#### DetoxNearMe

```env
DATABASE_URL="postgresql://user:pass@sql-steelgem:5432/detoxnearme"
NEXT_PUBLIC_API_URL="https://cms.detoxnearme.com"
NODE_ENV="production"
```

#### Edge Treatment & Forge Recovery

```env
CONTENTFUL_SPACE_ID="your_space_id"
CONTENTFUL_ACCESS_TOKEN="your_access_token"
CONTENTFUL_PREVIEW_ACCESS_TOKEN="your_preview_token"
CONTENTFUL_ENVIRONMENT="master"
NODE_ENV="production"
```

## Port Assignments

| Application | Port | Architecture |
|------------|------|--------------|
| DetoxNearMe | 3000 | Pages Router |
| Edge Treatment | 3001 | App Router v14-v15 |
| Forge Recovery | 3002 | App Router v14-v15 |

## Deployment Checklist

- [ ] Base VPS setup completed (`./scripts/vps-setup.sh`)
- [ ] NVM and Node.js installed (`./scripts/services.sh nvm`)
- [ ] SSL certificates installed (`./scripts/services.sh nextjs-ssl`)
- [ ] NGINX optimized (`./scripts/services.sh nextjs-nginx`)
- [ ] Application directories created (`/var/www/apps/`)
- [ ] Environment variables configured (`.env.local` files)
- [ ] Source code transferred and built
- [ ] PM2 processes started (`pm2 start ecosystem.config.js`)
- [ ] NGINX sites enabled and tested
- [ ] DNS pointed to node-steelgem IP
- [ ] Health checks passing

## Monitoring Commands

```bash
# View all processes
pm2 list

# Monitor resources
pm2 monit

# View logs
pm2 logs

# Check specific app
pm2 logs detoxnearme
pm2 describe detoxnearme

# NGINX status
systemctl status nginx
nginx -t

# Test endpoints
curl -I https://www.detoxnearme.com
curl -I https://www.theedgetreatment.com
curl -I https://www.theforgerecovery.com
```

## Troubleshooting

### PM2 Issues

```bash
# Restart all processes
pm2 restart all

# Delete and recreate
pm2 delete all
pm2 start ecosystem.config.js

# Check logs for errors
pm2 logs --err --lines 100
```

### NGINX Issues

```bash
# Test configuration
nginx -t

# View error logs
tail -f /var/log/nginx/error.log

# Restart NGINX
systemctl restart nginx
```

### Port Conflicts

```bash
# Check what's using a port
lsof -i :3000
ss -tlnp | grep 3000

# Kill process if needed
kill -9 <PID>
```

## Related Documentation

- [NODE-STEELGEM-SETUP.md](../../docs/NODE-STEELGEM-SETUP.md) - Complete setup guide
- [NEXTJS-DEPLOYMENT.md](../../docs/NEXTJS-DEPLOYMENT.md) - Deployment functions
- [NEXTJS-QUICKSTART.md](../../docs/NEXTJS-QUICKSTART.md) - Quick start examples

---

**Last Updated**: February 7, 2026
