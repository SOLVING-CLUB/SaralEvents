export default function Loading() {
  return (
    <div className="min-h-screen bg-white flex items-center justify-center">
      <div className="text-center">
        <div className="relative">
          <div className="animate-spin rounded-full h-32 w-32 border-b-4 border-yellow-600 mx-auto mb-4"></div>
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="w-16 h-16 bg-gradient-to-r from-yellow-400 to-orange-400 rounded-full flex items-center justify-center">
              <span className="text-2xl">🎉</span>
            </div>
          </div>
        </div>
        <h2 className="text-xl font-semibold text-gray-900 mb-2">Loading Saral Events</h2>
        <p className="text-gray-600">Preparing your event planning experience...</p>
      </div>
    </div>
  )
}
