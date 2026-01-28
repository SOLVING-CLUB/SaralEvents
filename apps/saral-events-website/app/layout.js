import Script from "next/script";
import "./globals.css";

export const metadata = {
  title: "Saral Events - Plan Less, Celebrate More",
  description: "Your one-stop solution for all event planning needs...",
  keywords: "event planning, wedding planning, catering, photography, ...",
  openGraph: {
    title: "Saral Events",
    description: "Your one-stop solution for all event planning needs...",
    url: "https://saralevents.com",
    siteName: "Saral Events",
    images: [
      {
        url: "/logo.png",
        width: 1200,
        height: 630,
        alt: "Saral Events Logo",
      },
    ],
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Saral Events - Plan Less, Celebrate More",
    description: "Your one-stop solution for all event planning needs.",
    images: ["/logo.png"],
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        {/* ✅ Favicon & Apple icons */}
        <link rel="icon" href="/favicon.ico" />
        <link rel="apple-touch-icon" href="/logo.png" />

        {/* ✅ Web App support */}
        <meta name="theme-color" content="#d97706" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <meta name="format-detection" content="telephone=no" />
      </head>
      <body className="antialiased">
        {children}

        {/* ✅ JSON-LD Schema */}
        <Script
          id="schema-org"
          type="application/ld+json"
          strategy="afterInteractive"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "Organization",
              name: "Saral Events",
              url: "https://saralevents.com",
              logo: "https://saralevents.com/logo.png",
              sameAs: [
                "https://facebook.com/saralevents",
                "https://www.instagram.com/saral_events_?igsh=dnBxcTVkZmZmbjly",
                "https://www.linkedin.com/company/nexus-eventers/",
                "https://twitter.com/saralevents"
              ],
            }),
          }}
        />
      </body>
    </html>
  );
}
