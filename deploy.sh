#!/bin/bash
# Quick deployment script for self-hosted deployment

echo "🚀 Starting deployment..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}PM2 not found. Installing PM2...${NC}"
    sudo npm install -g pm2
fi

# Deploy Single Web App (Landing + Admin)
echo -e "${GREEN}📦 Building Web App (Landing + Admin)...${NC}"
cd apps/company_web
npm install
npm run build

echo -e "${GREEN}🚀 Starting Web App on port 3005...${NC}"
pm2 delete company-web 2>/dev/null || true
pm2 start npm --name "company-web" -- start
pm2 save

# Return to root
cd ../..

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Web App (Landing + Admin): http://localhost:3005"
echo ""
echo "Next steps:"
echo "1. Configure nginx with: sudo cp nginx.conf /etc/nginx/sites-available/saralevents.com"
echo "2. Enable site: sudo ln -s /etc/nginx/sites-available/saralevents.com /etc/nginx/sites-enabled/"
echo "3. Test nginx: sudo nginx -t"
echo "4. Reload nginx: sudo systemctl reload nginx"
echo ""
echo "View logs:"
echo "  pm2 logs company-web"
