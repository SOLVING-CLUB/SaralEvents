import React from "react"
import clsx from "clsx"

const googlePlayIcon = (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M3 20.5V3.5c0-.59.34-1.11.84-1.35L13.69 12 3.84 21.85c-.5-.25-.84-.76-.84-1.35m13.81-5.38L6.05 21.34l8.49-8.49 2.27 2.27m3.35-4.31c.34.27.59.69.59 1.19 0 .5-.22.9-.57 1.18l-2.29 1.32L15.39 12l2.5-2.5 2.27 1.31M6.05 2.66l10.76 6.22-2.27 2.27L6.05 2.66Z" />
  </svg>
)

const appleIcon = (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z" />
  </svg>
)

/**
 * Reusable store download button used across the site to keep branding consistent.
 */
export default function AppStoreButton({
  platform = "android",
  href,
  onClick,
  tone = "dark",
  className = "",
}) {
  const isAndroid = platform === "android"
  const palette =
    tone === "light"
      ? "bg-white text-green-700 hover:bg-white/90 shadow"
      : "bg-black text-white hover:bg-gray-800 shadow-lg"

  const baseClasses =
    "inline-flex items-center px-4 py-3 rounded-xl transition-all duration-300 transform hover:scale-105 min-w-[160px]"

  const content = (
    <>
      <span className="mr-3 flex-shrink-0">{isAndroid ? googlePlayIcon : appleIcon}</span>
      <span className="text-left leading-tight">
        <span className="block text-xs">{isAndroid ? "Get it on" : "Download on the"}</span>
        <span className="block text-sm font-semibold">{isAndroid ? "Google Play" : "App Store"}</span>
      </span>
    </>
  )

  if (href) {
    return (
      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className={clsx(baseClasses, palette, className)}
      >
        {content}
      </a>
    )
  }

  return (
    <button onClick={onClick} className={clsx(baseClasses, palette, className)}>
      {content}
    </button>
  )
}

