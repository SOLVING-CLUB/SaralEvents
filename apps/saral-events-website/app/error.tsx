"use client"

import { useEffect } from "react"

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="min-h-screen bg-white flex items-center justify-center px-4">
      <div className="text-center max-w-md">
        <div className="mb-8">
          <div className="w-24 h-24 bg-gradient-to-r from-yellow-400 to-orange-400 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-4xl">⚠️</span>
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Something went wrong!</h1>
          <p className="text-gray-600 mb-6">
            We're sorry, but there was an error loading the page. Please try refreshing or contact support if the
            problem persists.
          </p>
        </div>

        <div className="space-y-4">
          <button
            onClick={reset}
            className="w-full bg-gradient-to-r from-yellow-600 to-orange-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-yellow-700 hover:to-orange-700 transition-all duration-300"
          >
            Try Again
          </button>

          <button
            onClick={() => (window.location.href = "/")}
            className="w-full border-2 border-yellow-600 text-yellow-600 px-6 py-3 rounded-xl font-semibold hover:bg-yellow-600 hover:text-white transition-all duration-300"
          >
            Go to Homepage
          </button>
        </div>

        <div className="mt-8 text-sm text-gray-500">
          <p>Need help? Contact us at:</p>
          <a href="mailto:contactus@saralevents.com" className="text-yellow-600 hover:underline">
          contactus@saralevents.com
          </a>
        </div>
      </div>
    </div>
  )
}
