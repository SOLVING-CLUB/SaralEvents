"use client"

import { useEffect, useState, useRef } from 'react'
import { createClient } from '@/lib/supabase'
import { Star, ThumbsUp, ThumbsDown, MessageSquare, Filter } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import type { RealtimeChannel } from '@supabase/supabase-js'

interface Review {
  id: string
  rating: number
  comment: string | null
  created_at: string
  user_id: string
  service_id: string | null
  vendor_id: string | null
  user_name?: string | null
  service_name?: string | null
  vendor_name?: string | null
  profiles?: { full_name: string } | null
  services?: { name: string } | null
  vendor_profiles?: { business_name: string } | null
}

export default function ReviewsPage() {
  const supabase = createClient()
  const [reviews, setReviews] = useState<Review[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [ratingFilter, setRatingFilter] = useState<number | 'all'>('all')
   // Filter by vendor and quickly see bad reviews
  const [vendorFilter, setVendorFilter] = useState<string>('all')
  const [selectedServiceName, setSelectedServiceName] = useState<string | null>(null)
  const [showVendorBrowser, setShowVendorBrowser] = useState(false)
  const [showNegativeOnly, setShowNegativeOnly] = useState(false)
  const channelRef = useRef<RealtimeChannel | null>(null)

  useEffect(() => {
    loadReviews()
    
    // Set up real-time subscription
    const channel = supabase
      .channel('reviews_realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'service_reviews',
        },
        () => {
          // Reload reviews when any change occurs
          loadReviews()
        }
      )
      .subscribe()
    
    channelRef.current = channel

    // Cleanup on unmount
    return () => {
      channel.unsubscribe()
    }
  }, [])

  async function loadReviews() {
    setLoading(true)
    setError(null)
    
    const { data, error } = await supabase
      // Use dedicated table for service reviews to avoid conflicts
      .from('service_reviews')
      .select(`
        id,
        rating,
        comment,
        created_at,
        user_id,
        service_id,
        vendor_id,
        user_name,
        service_name,
        vendor_name,
        profiles(full_name),
        services!service_reviews_service_id_fkey(name),
        vendor_profiles!service_reviews_vendor_id_fkey(business_name)
      `)
      .order('created_at', { ascending: false })
      .limit(200)
    
    if (error) {
      setError(error.message)
    } else {
      // Transform Supabase response: arrays to single objects
      const transformedData = (data || []).map((review: any) => ({
        ...review,
        profiles: Array.isArray(review.profiles) && review.profiles.length > 0 
          ? review.profiles[0] 
          : null,
        services: Array.isArray(review.services) && review.services.length > 0 
          ? review.services[0] 
          : null,
        vendor_profiles: Array.isArray(review.vendor_profiles) && review.vendor_profiles.length > 0 
          ? review.vendor_profiles[0] 
          : null,
      })) as Review[]
      setReviews(transformedData)
    }
    setLoading(false)
  }

  const filteredReviews = reviews.filter(review => {
    const vendorName =
      review.vendor_profiles?.business_name ||
      review.vendor_name ||
      null

    if (vendorFilter !== 'all' && vendorName !== vendorFilter) {
      return false
    }
    const serviceName = review.services?.name || review.service_name || null
    if (selectedServiceName && serviceName !== selectedServiceName) {
      return false
    }
    if (showNegativeOnly && review.rating > 2) {
      return false
    }
    if (ratingFilter !== 'all' && review.rating !== ratingFilter) return false
    if (search) {
      const q = search.toLowerCase()
      const userName = review.profiles?.full_name?.toLowerCase() || ''
      const serviceName =
        (review.services?.name || review.service_name || '').toLowerCase()
      const vendorName =
        (review.vendor_profiles?.business_name || review.vendor_name || '').toLowerCase()
      const comment = review.comment?.toLowerCase() || ''
      if (!userName.includes(q) && !serviceName.includes(q) && !vendorName.includes(q) && !comment.includes(q)) {
        return false
      }
    }
    return true
  })

  const vendorOptions = Array.from(
    new Set(
      reviews
        .map((r) => r.vendor_profiles?.business_name || r.vendor_name || null)
        .filter((v): v is string => !!v)
    )
  ).sort()

  // Build vendor -> services summaries (for drilldown UI)
  const vendorSummaries = vendorOptions.map((vendorName) => {
    const vendorReviews = reviews.filter((review) => {
      const vrVendorName =
        review.vendor_profiles?.business_name || review.vendor_name || null
      return vrVendorName === vendorName
    })

    const vendorAvg =
      vendorReviews.length > 0
        ? vendorReviews.reduce((sum, r) => sum + r.rating, 0) / vendorReviews.length
        : 0

    const serviceNames = Array.from(
      new Set(
        vendorReviews
          .map(
            (r) =>
              r.services?.name ||
              r.service_name ||
              null
          )
          .filter((s): s is string => !!s)
      )
    ).sort()

    const services = serviceNames.map((serviceName) => {
      const serviceReviews = vendorReviews.filter((r) => {
        const rServiceName = r.services?.name || r.service_name || null
        return rServiceName === serviceName
      })
      const serviceAvg =
        serviceReviews.length > 0
          ? serviceReviews.reduce((sum, r) => sum + r.rating, 0) / serviceReviews.length
          : 0
      return {
        name: serviceName,
        averageRating: serviceAvg,
        reviewCount: serviceReviews.length,
      }
    })

    return {
      name: vendorName,
      averageRating: vendorAvg,
      reviewCount: vendorReviews.length,
      services,
    }
  })

  const overallAvgRating = reviews.length > 0 
    ? (reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length).toFixed(1)
    : '0'

  const filteredAvgRating = filteredReviews.length > 0
    ? (filteredReviews.reduce((sum, r) => sum + r.rating, 0) / filteredReviews.length).toFixed(1)
    : '0'
  
  const ratingCounts = [5, 4, 3, 2, 1].map(rating => ({
    rating,
    count: reviews.filter(r => r.rating === rating).length
  }))

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Reviews & Feedback</h1>
          <p className="text-gray-600">Customer reviews and ratings for services</p>
        </div>
        <Button onClick={loadReviews} disabled={loading}>
          {loading ? 'Refreshing...' : 'Refresh'}
        </Button>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-yellow-50 rounded-full">
              <Star className="h-6 w-6 text-yellow-500 fill-yellow-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Overall Average Rating</p>
              <p className="text-2xl font-bold text-gray-900">{overallAvgRating}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-blue-50 rounded-full">
              <MessageSquare className="h-6 w-6 text-blue-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Reviews</p>
              <p className="text-2xl font-bold text-gray-900">{reviews.length}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-green-50 rounded-full">
              <ThumbsUp className="h-6 w-6 text-green-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Positive (4-5★)</p>
              <p className="text-2xl font-bold text-gray-900">
                {reviews.filter(r => r.rating >= 4).length}
              </p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-red-50 rounded-full">
              <ThumbsDown className="h-6 w-6 text-red-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Negative (1-2★)</p>
              <p className="text-2xl font-bold text-gray-900">
                {reviews.filter(r => r.rating <= 2).length}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Filtered Stats (for current vendor/service filters) */}
      <div className="bg-white p-4 rounded-lg border border-gray-200">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-600">Average Rating (current filters)</p>
            <p className="text-2xl font-bold text-gray-900">{filteredAvgRating}</p>
          </div>
          <p className="text-sm text-gray-600">
            {filteredReviews.length} review{filteredReviews.length === 1 ? '' : 's'} matching filters
          </p>
        </div>
      </div>

      {/* Rating Distribution */}
      <div className="bg-white p-6 rounded-lg border border-gray-200">
        <h3 className="text-lg font-semibold mb-4">Rating Distribution</h3>
        <div className="space-y-2">
          {ratingCounts.map(({ rating, count }) => (
            <div key={rating} className="flex items-center gap-3">
              <div className="flex items-center w-16">
                <span className="text-sm font-medium">{rating}</span>
                <Star className="h-4 w-4 text-yellow-500 fill-yellow-500 ml-1" />
              </div>
              <div className="flex-1 bg-gray-100 rounded-full h-3">
                <div 
                  className="bg-yellow-500 rounded-full h-3"
                  style={{ width: reviews.length > 0 ? `${(count / reviews.length) * 100}%` : '0%' }}
                />
              </div>
              <span className="text-sm text-gray-600 w-12">{count}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg border border-gray-200">
        <div className="flex flex-wrap gap-4 items-center">
          <div className="flex-1 min-w-[200px]">
            <Input
              placeholder="Search by user, service, vendor, or comment..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="flex flex-wrap gap-4 items-center">
            <div className="flex items-center gap-2">
              <Filter className="h-4 w-4 text-gray-500" />
              <select
                className="h-10 rounded-md border border-input bg-background px-3 text-sm"
                value={ratingFilter}
                onChange={(e) =>
                  setRatingFilter(e.target.value === 'all' ? 'all' : Number(e.target.value))
                }
              >
                <option value="all">All ratings</option>
                <option value={5}>5 stars</option>
                <option value={4}>4 stars</option>
                <option value={3}>3 stars</option>
                <option value={2}>2 stars</option>
                <option value={1}>1 star</option>
              </select>
            </div>

            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-600">Vendor</span>
              <Button
                variant="outline"
                className="h-10 px-3 text-sm"
                onClick={() => setShowVendorBrowser((prev) => !prev)}
              >
                {vendorFilter === 'all' ? 'All vendors' : vendorFilter}
              </Button>
            </div>

            <label className="flex items-center gap-2 text-sm text-gray-700">
              <input
                type="checkbox"
                className="h-4 w-4"
                checked={showNegativeOnly}
                onChange={(e) => setShowNegativeOnly(e.target.checked)}
              />
              <span>Only 1–2★ (bad) reviews</span>
            </label>
          </div>
        </div>
      </div>

      {/* Vendor → Service drilldown browser */}
      {showVendorBrowser && vendorSummaries.length > 0 && (
        <div className="bg-white p-4 rounded-lg border border-gray-200">
          <div className="flex flex-col md:flex-row gap-6">
            {/* Vendors list */}
            <div className="md:w-1/3 space-y-2">
              <h3 className="text-sm font-semibold text-gray-700 mb-2">Vendors</h3>
              <button
                type="button"
                className={`w-full text-left px-3 py-2 rounded-md text-sm ${
                  vendorFilter === 'all'
                    ? 'bg-blue-50 text-blue-700 border border-blue-200'
                    : 'hover:bg-gray-50 text-gray-700 border border-transparent'
                }`}
                onClick={() => {
                  setVendorFilter('all')
                  setSelectedServiceName(null)
                }}
              >
                All vendors
              </button>
              {vendorSummaries.map((vendor) => (
                <button
                  key={vendor.name}
                  type="button"
                  className={`w-full text-left px-3 py-2 rounded-md text-sm border ${
                    vendorFilter === vendor.name
                      ? 'bg-blue-50 text-blue-700 border-blue-300'
                      : 'bg-white text-gray-700 hover:bg-gray-50 border-gray-200'
                  }`}
                  onClick={() => {
                    setVendorFilter(vendor.name)
                    setSelectedServiceName(null)
                  }}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{vendor.name}</span>
                    <span className="text-xs text-gray-500">
                      {vendor.averageRating.toFixed(1)}★ ({vendor.reviewCount})
                    </span>
                  </div>
                </button>
              ))}
            </div>

            {/* Services for selected vendor */}
            <div className="md:flex-1">
              <h3 className="text-sm font-semibold text-gray-700 mb-2">
                {vendorFilter === 'all' ? 'Services (all vendors)' : `Services for ${vendorFilter}`}
              </h3>
              <div className="space-y-2">
                {(vendorFilter === 'all'
                  ? vendorSummaries.flatMap((vendor) =>
                      vendor.services.map((service) => ({
                        ...service,
                        vendorName: vendor.name,
                      }))
                    )
                  : vendorSummaries
                      .find((v) => v.name === vendorFilter)
                      ?.services.map((service) => ({
                        ...service,
                        vendorName: vendorFilter,
                      })) || []
                ).map((service) => (
                  <button
                    key={`${service.vendorName}-${service.name}`}
                    type="button"
                    className={`w-full text-left px-3 py-2 rounded-md text-sm border ${
                      selectedServiceName === service.name
                        ? 'bg-green-50 text-green-700 border-green-300'
                        : 'bg-white text-gray-700 hover:bg-gray-50 border-gray-200'
                    }`}
                    onClick={() => setSelectedServiceName(service.name)}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <span className="font-medium">{service.name}</span>
                        <span className="ml-2 text-xs text-gray-500">
                          ({service.vendorName})
                        </span>
                      </div>
                      <span className="text-xs text-gray-500">
                        {service.averageRating.toFixed(1)}★ ({service.reviewCount})
                      </span>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )
      }

      {/* Reviews List */}
      <div className="bg-white rounded-lg border border-gray-200">
        {loading ? (
          <div className="p-8 text-center text-gray-500">Loading reviews...</div>
        ) : error ? (
          <div className="p-8 text-center text-red-600">{error}</div>
        ) : filteredReviews.length === 0 ? (
          <div className="p-8 text-center text-gray-500">No reviews found</div>
        ) : (
          <div className="divide-y divide-gray-200">
            {filteredReviews.map((review) => (
              <div key={review.id} className="p-4 hover:bg-gray-50">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-medium text-gray-900">
                        {review.profiles?.full_name || review.user_name || 'Anonymous'}
                      </span>
                      <div className="flex items-center">
                        {[1, 2, 3, 4, 5].map((star) => (
                          <Star
                            key={star}
                            className={`h-4 w-4 ${
                              star <= review.rating
                                ? 'text-yellow-500 fill-yellow-500'
                                : 'text-gray-300'
                            }`}
                          />
                        ))}
                      </div>
                    </div>
                    <div className="text-sm text-gray-500 mb-2">
                      Service:{' '}
                      {review.services?.name ||
                        review.service_name ||
                        'N/A'}{' '}
                      • Vendor:{' '}
                      {review.vendor_profiles?.business_name ||
                        review.vendor_name ||
                        'N/A'}
                    </div>
                    {review.comment && (
                      <p className="text-gray-700">{review.comment}</p>
                    )}
                  </div>
                  <span className="text-xs text-gray-500">
                    {new Date(review.created_at).toLocaleDateString()}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

