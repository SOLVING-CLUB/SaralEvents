/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // basePath will be set via environment variable for production
  // For nginx reverse proxy: don't set basePath (nginx strips /admin prefix)
  // For Vercel: set basePath to /admin
  basePath: process.env.NEXT_PUBLIC_BASE_PATH || '',
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
  },
};

export default nextConfig;

