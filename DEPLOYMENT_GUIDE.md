# Deployment Guide: Saral Events Website & Admin Dashboard

This guide explains how to deploy both `saral-events-website` (landing page) and `company_web` (admin dashboard) on the same domain `saralevents.com`.

## Architecture

- **Landing Page**: `saralevents.com/` → `apps/saral-events-website`
- **Admin Dashboard**: `saralevents.com/admin` → `apps/company_web`

## Deployment Options

### Option 1: Vercel Deployment (Recommended)

Vercel is the easiest option for Next.js applications.

#### Step 1: Deploy Landing Page

1. **Connect Repository to Vercel**
   - Go to [Vercel Dashboard](https://vercel.com/dashboard)
   - Click "Add New Project"
   - Import your GitHub repository

2. **Configure Landing Page Project**
   - **Root Directory**: `apps/saral-events-website`
   - **Framework Preset**: Next.js
   - **Build Command**: `npm run build` (or `cd apps/saral-events-website && npm run build`)
   - **Output Directory**: `.next`
   - **Install Command**: `npm install`

3. **Set Environment Variables** (if needed)
   - Add any required environment variables in Vercel dashboard

4. **Deploy**
   - Click "Deploy"
   - Once deployed, note the deployment URL (e.g., `saral-events-website.vercel.app`)

#### Step 2: Deploy Admin Dashboard

1. **Create Second Project in Vercel**
   - Click "Add New Project" again
   - Import the same GitHub repository

2. **Configure Admin Dashboard Project**
   - **Root Directory**: `apps/company_web`
   - **Framework Preset**: Next.js
   - **Build Command**: `npm run build` (or `cd apps/company_web && npm run build`)
   - **Output Directory**: `.next`
   - **Install Command**: `npm install`

3. **Set Base Path Environment Variable**
   - Go to **Settings > Environment Variables**
   - Add: `NEXT_PUBLIC_BASE_PATH` = `/admin`

4. **Set Other Environment Variables**
   - Add Supabase and other required environment variables

5. **Deploy**
   - Click "Deploy"
   - Note the deployment URL (e.g., `company-web.vercel.app`)

#### Step 3: Configure Domain Routing

1. **Add Domain to Landing Page Project**
   - Go to landing page project settings
   - Navigate to **Domains**
   - Add `saralevents.com` and `www.saralevents.com`
   - Follow DNS configuration instructions

2. **Configure Rewrites in Landing Page Project**
   - The `vercel.json` file in `apps/saral-events-website` is already configured
   - **IMPORTANT**: Update the `destination` URL in `apps/saral-events-website/vercel.json` with your actual company_web Vercel deployment URL
   - After deploying company_web, copy its deployment URL and update the vercel.json file
   - Or configure rewrites via Vercel Dashboard:
     - Go to **Settings > Rewrites**
     - Add rewrite rule:
       ```
       Source: /admin/:path*
       Destination: https://your-company-web-url.vercel.app/:path*
       ```

#### Step 4: Update Company Web Configuration

The `next.config.mjs` in `company_web` is already configured to use `NEXT_PUBLIC_BASE_PATH`. Make sure this environment variable is set to `/admin` in Vercel.

---

### Option 2: Self-Hosted with Nginx (VPS/Server)

For deploying on your own server (VPS, AWS EC2, DigitalOcean, etc.)

#### Prerequisites

- Ubuntu/Debian server
- Node.js 18+ installed
- Nginx installed
- Domain `saralevents.com` pointing to your server IP
- SSL certificate (Let's Encrypt recommended)

#### Step 1: Install Dependencies

```bash
# Install Node.js (if not installed)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Nginx
sudo apt-get update
sudo apt-get install -y nginx

# Install PM2 for process management
sudo npm install -g pm2
```

#### Step 2: Clone and Build Landing Page

```bash
# Navigate to your project directory
cd /var/www/saralevents  # or your preferred directory

# Clone repository (if not already cloned)
git clone <your-repo-url> .

# Install dependencies
cd apps/saral-events-website
npm install

# Build the application
npm run build

# Start with PM2
pm2 start npm --name "landing-page" -- start
pm2 save
pm2 startup  # Follow instructions to enable auto-start
```

#### Step 3: Clone and Build Admin Dashboard

```bash
# In the same project directory
cd apps/company_web
npm install

# Build the application
npm run build

# Start with PM2 (on port 3005)
pm2 start npm --name "admin-dashboard" -- start
pm2 save
```

#### Step 4: Configure Nginx

1. **Copy nginx configuration**
   ```bash
   sudo cp nginx.conf /etc/nginx/sites-available/saralevents.com
   sudo ln -s /etc/nginx/sites-available/saralevents.com /etc/nginx/sites-enabled/
   ```

2. **Update nginx.conf** if needed:
   - Adjust ports if your apps run on different ports
   - Update server_name if using different domain

3. **Test Nginx configuration**
   ```bash
   sudo nginx -t
   ```

4. **Reload Nginx**
   ```bash
   sudo systemctl reload nginx
   ```

#### Step 5: Configure SSL (Let's Encrypt)

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d saralevents.com -d www.saralevents.com

# Certbot will automatically update nginx.conf with SSL configuration
# Test auto-renewal
sudo certbot renew --dry-run
```

#### Step 6: Update Firewall

```bash
# Allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw enable
```

#### Step 7: Verify Deployment

- Visit `http://saralevents.com` - should show landing page
- Visit `http://saralevents.com/admin` - should show admin dashboard login
- After SSL: `https://saralevents.com` and `https://saralevents.com/admin`

---

### Option 3: Docker Deployment

Create `docker-compose.yml` in project root:

```yaml
version: '3.8'

services:
  landing-page:
    build:
      context: ./apps/saral-events-website
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  admin-dashboard:
    build:
      context: ./apps/company_web
      dockerfile: Dockerfile
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_BASE_PATH=/admin
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - landing-page
      - admin-dashboard
    restart: unless-stopped
```

Create `Dockerfile` in each app directory:

**apps/saral-events-website/Dockerfile:**
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
EXPOSE 3000
CMD ["npm", "start"]
```

**apps/company_web/Dockerfile:**
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
EXPOSE 3005
CMD ["npm", "start"]
```

Deploy:
```bash
docker-compose up -d
```

---

## Environment Variables

### Landing Page (`saral-events-website`)
Set these in your deployment platform:
- Any API keys or environment variables required by the landing page

### Admin Dashboard (`company_web`)
Set these in your deployment platform:
- `NEXT_PUBLIC_BASE_PATH=/admin` (for Vercel, optional for nginx)
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Any other required environment variables

---

## Troubleshooting

### Issue: `/admin` shows 404
- **Nginx**: Check that rewrite rule is correct and nginx is reloaded
- **Vercel**: Verify rewrite rule is configured correctly
- **Company Web**: Ensure `NEXT_PUBLIC_BASE_PATH=/admin` is set (for Vercel)

### Issue: Static assets not loading on `/admin`
- Check that `/_next` paths are properly proxied
- Verify basePath configuration

### Issue: Routes not working correctly
- Clear browser cache
- Check browser console for errors
- Verify both apps are running and accessible

---

## Monitoring & Maintenance

### PM2 Commands (Self-Hosted)
```bash
# View logs
pm2 logs landing-page
pm2 logs admin-dashboard

# Restart apps
pm2 restart landing-page
pm2 restart admin-dashboard

# View status
pm2 status
```

### Nginx Logs
```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log
```

---

## Notes

- The landing page (`saral-events-website`) serves the root domain
- The admin dashboard (`company_web`) is accessible at `/admin`
- No buttons or links are needed - users can directly navigate to `/admin` via URL
- Both apps maintain their own routing internally
- Static assets and API routes are properly proxied
