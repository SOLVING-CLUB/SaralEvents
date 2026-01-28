/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
  },
  webpack: (config, { dev }) => {
    // Windows + OneDrive frequently breaks Next/Webpack filesystem cache inside `.next/cache`
    // causing ENOENT for *.pack.gz and flaky dev reloads. Disable FS cache in dev.
    if (dev) {
      config.cache = false
    }
    return config
  },
};

export default nextConfig;

