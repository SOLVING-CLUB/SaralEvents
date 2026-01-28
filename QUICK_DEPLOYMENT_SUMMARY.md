# Quick Deployment Summary

## 🎯 Goal
- **Landing Page**: `saralevents.com/` → `apps/saral-events-website`
- **Admin Dashboard**: `saralevents.com/admin` → `apps/company_web`

## 🚀 Quick Start Options

### Option 1: Vercel (Easiest - Recommended)

1. **Deploy Landing Page**
   - Go to [Vercel Dashboard](https://vercel.com)
   - Import repository
   - Set Root Directory: `apps/saral-events-website`
   - Deploy

2. **Deploy Admin Dashboard**
   - Create new project in Vercel
   - Same repository
   - Set Root Directory: `apps/company_web`
   - Add Environment Variable: `NEXT_PUBLIC_BASE_PATH=/admin`
   - Deploy

3. **Configure Routing**
   - In landing page project settings
   - Add domain: `saralevents.com`
   - Update `apps/saral-events-website/vercel.json` with company_web URL
   - Or add rewrite in Vercel Dashboard: `/admin/:path*` → `https://your-company-web-url.vercel.app/:path*`

### Option 2: Self-Hosted with Nginx

1. **Build & Start Apps**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

2. **Configure Nginx**
   ```bash
   sudo cp nginx.conf /etc/nginx/sites-available/saralevents.com
   sudo ln -s /etc/nginx/sites-available/saralevents.com /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **Setup SSL**
   ```bash
   sudo certbot --nginx -d saralevents.com -d www.saralevents.com
   ```

## 📝 Important Notes

- No buttons needed - users navigate directly to `/admin` via URL
- Both apps run independently
- Landing page serves root domain
- Admin dashboard accessible at `/admin` path
- Static assets and API routes are properly proxied

## 📚 Full Documentation

See `DEPLOYMENT_GUIDE.md` for detailed instructions.
