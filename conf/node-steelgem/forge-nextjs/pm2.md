# Forge Recovery PM2 Configuration

## Application Details

- **Name**: forge_nextjs
- **Domain**: <https://www.theforgerecovery.com>
- **Port**: 3002
- **Architecture**: NextJS App Router (v14-v15)
- **Node Version**: v20.19.5 (specified in `.nvmrc`)
- **CMS**: Contentful

## PM2 Process Configuration

### Cluster Mode (Recommended)

```bash
pm2 start npm --name "forge_nextjs" \
  -i 2 \
  --cwd /var/www/apps/forge_nextjs \
  -- run start -- -p 3002

pm2 save
```

### Using Ecosystem File

```bash
# Start all applications (including forge_nextjs)
cd /var/www/apps
pm2 start ecosystem.config.js

# Start only forge_nextjs
pm2 start ecosystem.config.js --only forge_nextjs
```

## Process Details

```
┌────┬──────────────┬─────────────┬─────────┬─────────┬──────────┬────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name         │ namespace   │ version │ mode    │ pid      │ uptime │ ↺    │ status    │ cpu      │ mem      │
├────┼──────────────┼─────────────┼─────────┼─────────┼──────────┼────────┼──────┼───────────┼──────────┼──────────┤
│ 4  │ forge_nextjs │ default     │ 1.0.0   │ cluster │ 12349    │ 2D     │ 0    │ online    │ 0.4%     │ 170.0mb  │
│ 5  │ forge_nextjs │ default     │ 1.0.0   │ cluster │ 12350    │ 2D     │ 0    │ online    │ 0.3%     │ 165.0mb  │
└────┴──────────────┴─────────────┴─────────┴─────────┴──────────┴────────┴──────┴───────────┴──────────┴──────────┘
```

## Detailed Process Information

```bash
pm2 describe forge_nextjs
```

```
┌───────────────────┬──────────────────────────────────────────────────┐
│ status            │ online                                           │
│ name              │ forge_nextjs                                     │
│ namespace         │ default                                          │
│ version           │ 1.0.0                                            │
│ restarts          │ 0                                                │
│ uptime            │ 2D                                               │
│ script path       │ /root/.nvm/versions/node/v20.19.5/bin/npm        │
│ script args       │ run start -- -p 3002                             │
│ error log path    │ /var/log/pm2/forge-error.log                     │
│ out log path      │ /var/log/pm2/forge-out.log                       │
│ pid path          │ /root/.pm2/pids/forge_nextjs-4.pid               │
│ interpreter       │ node                                             │
│ interpreter args  │ N/A                                              │
│ exec cwd          │ /var/www/apps/forge_nextjs                       │
│ exec mode         │ cluster_mode                                     │
│ node.js version   │ 20.19.5                                          │
│ instances         │ 2                                                │
│ max memory        │ 1G                                               │
└───────────────────┴──────────────────────────────────────────────────┘
```

## App Router Architecture

Forge Recovery uses the **NextJS App Router** (v14-v15), similar to Edge Treatment:

```
/var/www/apps/forge_nextjs/
├── app/                          # App Router directory
│   ├── layout.tsx               # Root layout
│   ├── page.tsx                 # Home page
│   ├── programs/
│   │   └── page.tsx             # Programs page
│   ├── admissions/
│   │   └── page.tsx             # Admissions page
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
- **Sister Site to Edge**: Shares similar architecture and patterns

## Monitoring Commands

### View Logs

```bash
# Real-time logs
pm2 logs forge_nextjs

# Last 100 lines
pm2 logs forge_nextjs --lines 100

# Error logs only
pm2 logs forge_nextjs --err

# Raw log files
tail -f /var/log/pm2/forge-error.log
tail -f /var/log/pm2/forge-out.log
```

### Resource Monitoring

```bash
# Real-time monitor
pm2 monit

# Process details
pm2 describe forge_nextjs

# List all processes
pm2 list
```

### Health Check

```bash
# Test local endpoint
curl -I http://localhost:3002

# Test production endpoint
curl -I https://www.theforgerecovery.com

# Check if process is listening
ss -tlnp | grep 3002
```

## Management Commands

### Restart

```bash
# Graceful restart (zero-downtime)
pm2 reload forge_nextjs

# Hard restart
pm2 restart forge_nextjs

# Restart all processes
pm2 restart all
```

### Stop/Start

```bash
# Stop process
pm2 stop forge_nextjs

# Start process
pm2 start forge_nextjs

# Delete process from PM2
pm2 delete forge_nextjs
```

### Scaling

```bash
# Scale to 4 instances
pm2 scale forge_nextjs 4

# Scale to 1 instance
pm2 scale forge_nextjs 1
```

## Environment Variables

Create `/var/www/apps/forge_nextjs/.env.local`:

```env
# Contentful CMS Configuration (Separate Space from Edge)
CONTENTFUL_SPACE_ID="your_forge_contentful_space_id"
CONTENTFUL_ACCESS_TOKEN="your_forge_contentful_access_token"
CONTENTFUL_PREVIEW_ACCESS_TOKEN="your_forge_contentful_preview_token"
CONTENTFUL_ENVIRONMENT="master"

# NextJS Configuration
NODE_ENV="production"
NEXT_TELEMETRY_DISABLED=1

# Optional: ISR Revalidation Secret
REVALIDATE_SECRET="your_forge_random_secret_key"

# Optional: Analytics (separate tracking from Edge)
# NEXT_PUBLIC_GA_ID="G-XXXXXXXXXX"
```

**Security**: Ensure `.env.local` has restricted permissions:

```bash
chmod 600 /var/www/apps/forge_nextjs/.env.local
chown root:root /var/www/apps/forge_nextjs/.env.local
```

## Build and Deployment

### Initial Deployment

```bash
# Navigate to app directory
cd /var/www/apps/forge_nextjs

# Install dependencies
npm ci --production

# Build application
npm run build

# Start with PM2
pm2 start ecosystem.config.js --only forge_nextjs

# Save PM2 configuration
pm2 save
```

### Update Deployment

```bash
# Pull latest code
cd /var/www/apps/forge_nextjs
git pull origin main

# Install dependencies
npm ci --production

# Rebuild application
npm run build

# Reload PM2 process (zero-downtime)
pm2 reload forge_nextjs
```

## Contentful Integration

### ISR Revalidation

Trigger on-demand revalidation when content updates in Contentful:

```bash
# Revalidate specific path
curl -X POST https://www.theforgerecovery.com/api/revalidate \
  -H "Content-Type: application/json" \
  -d '{"secret": "your_forge_revalidate_secret", "path": "/programs"}'
```

### Contentful Webhook

Configure Contentful webhook to automatically revalidate on content publish:

**Webhook URL**: `https://www.theforgerecovery.com/api/revalidate`
**Method**: POST
**Headers**: `Content-Type: application/json`
**Triggers**: Entry publish, Entry unpublish

**Note**: Forge Recovery uses a **separate Contentful Space** from Edge Treatment.

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
# Test Contentful connectivity (Forge Space)
curl -H "Authorization: Bearer YOUR_FORGE_TOKEN" \
  "https://cdn.contentful.com/spaces/YOUR_FORGE_SPACE_ID/entries"

# Check environment variables
pm2 env forge_nextjs

# View logs for API errors
pm2 logs forge_nextjs --err --lines 50
```

### Build Failures

```bash
# Check Node version
node --version
cat /var/www/apps/forge_nextjs/.nvmrc

# Clear Next.js cache
cd /var/www/apps/forge_nextjs
rm -rf .next

# Rebuild
npm run build
```

### Port Conflicts

```bash
# Check what's using port 3002
lsof -i :3002
ss -tlnp | grep 3002

# Kill process if needed
kill -9 <PID>

# Restart forge_nextjs
pm2 restart forge_nextjs
```

### High Memory Usage

```bash
# Check memory per instance
pm2 describe forge_nextjs

# Reduce instance count
pm2 scale forge_nextjs 1

# Adjust memory limit in ecosystem.config.js
```

## Backup and Recovery

### Configuration Backup

```bash
# Backup environment variables
cp /var/www/apps/forge_nextjs/.env.local \
   /root/backups/forge.env.$(date +%Y%m%d)

# Backup build output
tar -czf /root/backups/forge-build-$(date +%Y%m%d).tar.gz \
  /var/www/apps/forge_nextjs/.next
```

### Recovery

```bash
# Restore from backup
pm2 resurrect

# Or restart from ecosystem file
pm2 start /var/www/apps/ecosystem.config.js --only forge_nextjs
```

## Comparison with Edge Treatment

| Feature | Edge Treatment | Forge Recovery |
|---------|---------------|----------------|
| **Domain** | theedgetreatment.com | theforgerecovery.com |
| **Port** | 3001 | 3002 |
| **Contentful Space** | Separate | Separate |
| **Architecture** | App Router v14-v15 | App Router v14-v15 |
| **PM2 Instances** | 2 | 2 |
| **Shared Components** | ✅ Similar patterns | ✅ Similar patterns |

Both sites are sister sites sharing the same modern NextJS architecture but with separate:

- Contentful Spaces
- Environment variables
- PM2 processes
- NGINX configurations
- Domain names

## Related Files

- **NGINX Configuration**: `/etc/nginx/sites-available/forge_nextjs`
- **SSL Certificates**: `/etc/ssl/certs/cloudflare-origin-fullchain.pem`
- **Logs**: `/var/log/pm2/forge-*.log`
- **Application**: `/var/www/apps/forge_nextjs/`

---

**Last Updated**: February 7, 2026
**Application Version**: 1.0.0
**NextJS Version**: 14-15 (App Router)
**Node Version**: 20.19.5 LTS
