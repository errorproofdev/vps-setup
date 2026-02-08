# Edge Treatment PM2 Configuration

## Application Details

- **Name**: edge_nextjs
- **Domain**: <https://www.theedgetreatment.com>
- **Port**: 3001
- **Architecture**: NextJS App Router (v14-v15)
- **Node Version**: v20.19.5 (specified in `.nvmrc`)
- **CMS**: Contentful

## PM2 Process Configuration

### Cluster Mode (Recommended)

```bash
pm2 start npm --name "edge_nextjs" \
  -i 2 \
  --cwd /var/www/apps/edge_nextjs \
  -- run start -- -p 3001

pm2 save
```

### Using Ecosystem File

```bash
# Start all applications (including edge_nextjs)
cd /var/www/apps
pm2 start ecosystem.config.js

# Start only edge_nextjs
pm2 start ecosystem.config.js --only edge_nextjs
```

## Process Details

```
┌────┬──────────────┬─────────────┬─────────┬─────────┬──────────┬────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name         │ namespace   │ version │ mode    │ pid      │ uptime │ ↺    │ status    │ cpu      │ mem      │
├────┼──────────────┼─────────────┼─────────┼─────────┼──────────┼────────┼──────┼───────────┼──────────┼──────────┤
│ 2  │ edge_nextjs  │ default     │ 1.0.0   │ cluster │ 12347    │ 3D     │ 0    │ online    │ 0.3%     │ 165.0mb  │
│ 3  │ edge_nextjs  │ default     │ 1.0.0   │ cluster │ 12348    │ 3D     │ 0    │ online    │ 0.2%     │ 160.0mb  │
└────┴──────────────┴─────────────┴─────────┴─────────┴──────────┴────────┴──────┴───────────┴──────────┴──────────┘
```

## Detailed Process Information

```bash
pm2 describe edge_nextjs
```

```
┌───────────────────┬──────────────────────────────────────────────────┐
│ status            │ online                                           │
│ name              │ edge_nextjs                                      │
│ namespace         │ default                                          │
│ version           │ 1.0.0                                            │
│ restarts          │ 0                                                │
│ uptime            │ 3D                                               │
│ script path       │ /root/.nvm/versions/node/v20.19.5/bin/npm        │
│ script args       │ run start -- -p 3001                             │
│ error log path    │ /var/log/pm2/edge-error.log                      │
│ out log path      │ /var/log/pm2/edge-out.log                        │
│ pid path          │ /root/.pm2/pids/edge_nextjs-2.pid                │
│ interpreter       │ node                                             │
│ interpreter args  │ N/A                                              │
│ exec cwd          │ /var/www/apps/edge_nextjs                        │
│ exec mode         │ cluster_mode                                     │
│ node.js version   │ 20.19.5                                          │
│ instances         │ 2                                                │
│ max memory        │ 1G                                               │
└───────────────────┴──────────────────────────────────────────────────┘
```

## App Router Architecture

Edge Treatment uses the **NextJS App Router** (v14-v15) with the following structure:

```
/var/www/apps/edge_nextjs/
├── app/                          # App Router directory
│   ├── layout.tsx               # Root layout
│   ├── page.tsx                 # Home page
│   ├── about/
│   │   └── page.tsx             # About page
│   ├── contact/
│   │   └── page.tsx             # Contact page
│   └── api/                     # API routes
│       └── revalidate/
│           └── route.ts         # ISR revalidation
├── components/                   # React components
├── lib/                         # Utilities and helpers
│   └── contentful.ts            # Contentful API client
├── public/                      # Static assets
├── .next/                       # Build output
├── next.config.js               # NextJS configuration
└── .env.local                   # Environment variables
```

### Key Features

- **React Server Components**: Default for all components
- **Incremental Static Regeneration (ISR)**: Content updates from Contentful
- **Image Optimization**: Built-in NextJS image optimization
- **Metadata API**: SEO-optimized with dynamic metadata

## Monitoring Commands

### View Logs

```bash
# Real-time logs
pm2 logs edge_nextjs

# Last 100 lines
pm2 logs edge_nextjs --lines 100

# Error logs only
pm2 logs edge_nextjs --err

# Raw log files
tail -f /var/log/pm2/edge-error.log
tail -f /var/log/pm2/edge-out.log
```

### Resource Monitoring

```bash
# Real-time monitor
pm2 monit

# Process details
pm2 describe edge_nextjs

# List all processes
pm2 list
```

### Health Check

```bash
# Test local endpoint
curl -I http://localhost:3001

# Test production endpoint
curl -I https://www.theedgetreatment.com

# Check if process is listening
ss -tlnp | grep 3001
```

## Management Commands

### Restart

```bash
# Graceful restart (zero-downtime)
pm2 reload edge_nextjs

# Hard restart
pm2 restart edge_nextjs

# Restart all processes
pm2 restart all
```

### Stop/Start

```bash
# Stop process
pm2 stop edge_nextjs

# Start process
pm2 start edge_nextjs

# Delete process from PM2
pm2 delete edge_nextjs
```

### Scaling

```bash
# Scale to 4 instances
pm2 scale edge_nextjs 4

# Scale to 1 instance
pm2 scale edge_nextjs 1
```

## Environment Variables

Create `/var/www/apps/edge_nextjs/.env.local`:

```env
# Contentful CMS Configuration
CONTENTFUL_SPACE_ID="your_contentful_space_id"
CONTENTFUL_ACCESS_TOKEN="your_contentful_access_token"
CONTENTFUL_PREVIEW_ACCESS_TOKEN="your_contentful_preview_token"
CONTENTFUL_ENVIRONMENT="master"

# NextJS Configuration
NODE_ENV="production"
NEXT_TELEMETRY_DISABLED=1

# Optional: ISR Revalidation Secret
REVALIDATE_SECRET="your_random_secret_key"

# Optional: Analytics
# NEXT_PUBLIC_GA_ID="G-XXXXXXXXXX"
```

**Security**: Ensure `.env.local` has restricted permissions:

```bash
chmod 600 /var/www/apps/edge_nextjs/.env.local
chown root:root /var/www/apps/edge_nextjs/.env.local
```

## Build and Deployment

### Initial Deployment

```bash
# Navigate to app directory
cd /var/www/apps/edge_nextjs

# Install dependencies
npm ci --production

# Build application
npm run build

# Start with PM2
pm2 start ecosystem.config.js --only edge_nextjs

# Save PM2 configuration
pm2 save
```

### Update Deployment

```bash
# Pull latest code
cd /var/www/apps/edge_nextjs
git pull origin main

# Install dependencies
npm ci --production

# Rebuild application
npm run build

# Reload PM2 process (zero-downtime)
pm2 reload edge_nextjs
```

## Contentful Integration

### ISR Revalidation

Trigger on-demand revalidation when content updates in Contentful:

```bash
# Revalidate specific path
curl -X POST https://www.theedgetreatment.com/api/revalidate \
  -H "Content-Type: application/json" \
  -d '{"secret": "your_revalidate_secret", "path": "/about"}'
```

### Contentful Webhook

Configure Contentful webhook to automatically revalidate on content publish:

**Webhook URL**: `https://www.theedgetreatment.com/api/revalidate`
**Method**: POST
**Headers**: `Content-Type: application/json`
**Triggers**: Entry publish, Entry unpublish

## Performance Tuning

### App Router Optimizations

```javascript
// next.config.js
module.exports = {
  compress: true,
  poweredByHeader: false,

  experimental: {
    optimizePackageImports: ['lodash', 'date-fns', 'contentful']
  },

  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.ctfassets.net',
        pathname: '/**'
      }
    ]
  }
};
```

### ISR Cache Strategy

- **Static pages**: Pre-rendered at build time
- **ISR pages**: Revalidated on-demand or time-based
- **Dynamic pages**: Server-rendered per request

## Troubleshooting

### Contentful API Issues

```bash
# Test Contentful connectivity
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://cdn.contentful.com/spaces/YOUR_SPACE_ID/entries"

# Check environment variables
pm2 env edge_nextjs

# View logs for API errors
pm2 logs edge_nextjs --err --lines 50
```

### Build Failures

```bash
# Check Node version
node --version
cat /var/www/apps/edge_nextjs/.nvmrc

# Clear Next.js cache
cd /var/www/apps/edge_nextjs
rm -rf .next

# Rebuild
npm run build
```

### High Memory Usage

```bash
# Check memory per instance
pm2 describe edge_nextjs

# Reduce instance count
pm2 scale edge_nextjs 1

# Adjust memory limit in ecosystem.config.js
```

## Backup and Recovery

### Configuration Backup

```bash
# Backup environment variables
cp /var/www/apps/edge_nextjs/.env.local \
   /root/backups/edge.env.$(date +%Y%m%d)

# Backup build output
tar -czf /root/backups/edge-build-$(date +%Y%m%d).tar.gz \
  /var/www/apps/edge_nextjs/.next
```

### Recovery

```bash
# Restore from backup
pm2 resurrect

# Or restart from ecosystem file
pm2 start /var/www/apps/ecosystem.config.js --only edge_nextjs
```

## Related Files

- **NGINX Configuration**: `/etc/nginx/sites-available/edge_nextjs`
- **SSL Certificates**: `/etc/ssl/certs/cloudflare-origin-fullchain.pem`
- **Logs**: `/var/log/pm2/edge-*.log`
- **Application**: `/var/www/apps/edge_nextjs/`

---

**Last Updated**: February 7, 2026
**Application Version**: 1.0.0
**NextJS Version**: 14-15 (App Router)
**Node Version**: 20.19.5 LTS
