'use client'

import { useEffect, useState } from 'react'

export default function DownloadPage() {
  const [showPopup, setShowPopup] = useState(false)

  useEffect(() => {
    setShowPopup(true)
  }, [])

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      {showPopup && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/40 backdrop-blur-sm z-50">
          <div className="bg-white p-6 rounded-2xl shadow-lg w-80 text-center">
            <h2 className="text-xl font-bold mb-4">Download Sara Events App</h2>
            <p className="text-gray-600 mb-6">Choose your version</p>

            <a
              href="https://play.google.com/store/apps/details?id=com.userapp"
              className="block w-full bg-blue-600 text-white py-2 rounded-lg mb-3 hover:bg-blue-700 transition"
            >
              Download User App
            </a>

            <a
              href="https://play.google.com/store/apps/details?id=com.vendorapp"
              className="block w-full bg-green-600 text-white py-2 rounded-lg hover:bg-green-700 transition"
            >
              Download Vendor App
            </a>
          </div>
        </div>
      )}
    </div>
  )
}

