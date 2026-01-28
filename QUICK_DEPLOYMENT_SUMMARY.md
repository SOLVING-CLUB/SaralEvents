# Quick Deployment Summary

## 🎯 Goal
- **Single Web App**: `apps/company_web`
  - `saralevents.com/` → Landing page
  - `saralevents.com/admin` → Admin dashboard

## 🚀 Quick Start Options

### Option 1: Vercel (Easiest - Recommended)

1. **Deploy the single app**
   - Go to [Vercel Dashboard](https://vercel.com)
   - Import repository
   - Set **Root Directory**: `apps/company_web`
   - Deploy

2. **Add domain**
   - Project → Settings → Domains
   - Add `saralevents.com` and `www.saralevents.com`

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
- This is a **single Next.js app** now
- Landing page serves root domain (`/`)
- Admin dashboard is under `/admin/*`

## 📚 Full Documentation

See `DEPLOYMENT_GUIDE.md` for detailed instructions.
