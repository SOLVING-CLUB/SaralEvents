"use client"

import { useEffect, useState, useRef } from 'react'
import Link from 'next/link'
import { useNetworkStatus } from '@/hooks/useNetworkStatus'
import { safeQuery } from '@/lib/api-client'
import { 
  ShoppingBag, 
  MessageSquare, 
  Settings, 
  Store, 
  Users, 
  Megaphone,
  BarChart3,
  TrendingUp,
  TrendingDown,
  IndianRupee,
  Clock,
  XCircle,
  CheckCircle,
  Star,
  Activity
} from 'lucide-react'
import { 
  getDashboardStats, 
  getTopVendors, 
  getPopularServices,
  getVendorActivityStatus,
  type DashboardStats,
  type TopVendor,
  type PopularService,
  type VendorActivity
} from '@/lib/dashboard-queries'

export default function Dashboard() {
  const { isOnline } = useNetworkStatus()
  const abortControllerRef = useRef<AbortController | null>(null)
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [topVendors, setTopVendors] = useState<TopVendor[]>([])
  const [popularServices, setPopularServices] = useState<PopularService[]>([])
  const [vendorActivity, setVendorActivity] = useState<VendorActivity[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    // Cancel previous request if still pending
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
    }

    const controller = new AbortController()
    abortControllerRef.current = controller

    async function loadData() {
      if (!isOnline) {
        setError('No internet connection. Please check your network.')
        setLoading(false)
        return
      }

      try {
        setError(null)
        
        // Use Promise.allSettled to handle partial failures gracefully
        const results = await Promise.allSettled([
          safeQuery(
            async () => ({ data: await getDashboardStats(), error: null }),
            { signal: controller.signal, timeout: 30000, maxRetries: 3 }
          ),
          safeQuery(
            async () => ({ data: await getTopVendors(5), error: null }),
            { signal: controller.signal, timeout: 30000, maxRetries: 3 }
          ),
          safeQuery(
            async () => ({ data: await getPopularServices(5), error: null }),
            { signal: controller.signal, timeout: 30000, maxRetries: 3 }
          ),
          safeQuery(
            async () => ({ data: await getVendorActivityStatus(), error: null }),
            { signal: controller.signal, timeout: 30000, maxRetries: 3 }
          ),
        ])

        // Check if request was cancelled
        if (controller.signal.aborted) {
          return
        }

        // Process results
        if (results[0].status === 'fulfilled' && results[0].value.data) {
          setStats(results[0].value.data as DashboardStats)
        }
        if (results[1].status === 'fulfilled' && results[1].value.data) {
          setTopVendors(results[1].value.data as TopVendor[])
        }
        if (results[2].status === 'fulfilled' && results[2].value.data) {
          setPopularServices(results[2].value.data as PopularService[])
        }
        if (results[3].status === 'fulfilled' && results[3].value.data) {
          setVendorActivity(results[3].value.data as VendorActivity[])
        }

        // Check for errors
        const errors = results
          .map((r, i) => r.status === 'rejected' ? r.reason : (r.status === 'fulfilled' && r.value.error ? r.value.error : null))
          .filter(Boolean)
        
        if (errors.length > 0) {
          console.error('Error loading dashboard data:', errors)
          setError('Some data failed to load. Please refresh.')
        }
      } catch (error) {
        console.error('Error loading dashboard data:', error)
        setError('Failed to load dashboard data. Please refresh.')
      } finally {
        setLoading(false)
      }
    }
    
    loadData()

    return () => {
      controller.abort()
    }
  }, [isOnline])

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-4">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
        <p className="text-sm text-gray-600">Loading dashboard data...</p>
      </div>
    )
  }

  if (error && !stats) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-4">
        <p className="text-red-600">{error}</p>
        <button
          onClick={() => window.location.reload()}
          className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard Overview</h1>
        <p className="text-gray-600">Welcome to your admin dashboard</p>
      </div>

      {/* Primary Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Orders"
          value={stats?.totalOrders.toLocaleString() || '0'}
          icon={ShoppingBag}
          color="blue"
        />
        <StatCard
          title="Pending Approval"
          value={stats?.pendingApproval.toLocaleString() || '0'}
          icon={Clock}
          color="yellow"
        />
        <StatCard
          title="Cancelled Orders"
          value={stats?.cancelledOrders.toLocaleString() || '0'}
          icon={XCircle}
          color="red"
        />
        <StatCard
          title="Completed Orders"
          value={stats?.completedOrders.toLocaleString() || '0'}
          icon={CheckCircle}
          color="green"
        />
      </div>

      {/* Financial Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <StatCard
          title="Total Revenue"
          value={`₹${(stats?.totalRevenue || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`}
          icon={IndianRupee}
          color="green"
        />
        <StatCard
          title="Average Order Value"
          value={`₹${(stats?.averageOrderValue || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`}
          icon={TrendingUp}
          color="purple"
        />
        <StatCard
          title="Active Vendors"
          value={stats?.activeVendors.toLocaleString() || '0'}
          icon={Store}
          color="blue"
        />
      </div>

      {/* User Activity Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <StatCard
          title="Total Users"
          value={stats?.totalUsers.toLocaleString() || '0'}
          icon={Users}
          color="purple"
        />
        <StatCard
          title="Active Users (Monthly)"
          value={stats?.activeUsersMonthly.toLocaleString() || '0'}
          icon={Activity}
          color="blue"
        />
        <StatCard
          title="Active Users (Yearly)"
          value={stats?.activeUsersYearly.toLocaleString() || '0'}
          icon={Activity}
          color="green"
        />
      </div>

      {/* Top Vendors & Popular Services */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Performing Vendors */}
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900">Top Performing Vendors</h3>
            <Link href="/dashboard/vendors" className="text-sm text-blue-600 hover:underline">
              View all
            </Link>
          </div>
          {topVendors.length === 0 ? (
            <p className="text-gray-500 text-sm">No vendor data available</p>
          ) : (
            <div className="space-y-3">
              {topVendors.map((vendor, index) => (
                <div key={vendor.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center">
                    <span className="w-6 h-6 flex items-center justify-center bg-blue-100 text-blue-700 rounded-full text-sm font-medium mr-3">
                      {index + 1}
                    </span>
                    <div>
                      <p className="font-medium text-gray-900">{vendor.business_name}</p>
                      <p className="text-sm text-gray-500">{vendor.total_orders} orders</p>
                    </div>
                  </div>
                  <p className="font-semibold text-green-600">
                    ₹{vendor.total_revenue.toLocaleString('en-IN')}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Most Popular Services */}
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900">Most Popular Services</h3>
            <Link href="/dashboard/services" className="text-sm text-blue-600 hover:underline">
              View all
            </Link>
          </div>
          {popularServices.length === 0 ? (
            <p className="text-gray-500 text-sm">No service data available</p>
          ) : (
            <div className="space-y-3">
              {popularServices.map((service, index) => (
                <div key={service.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center">
                    <span className="w-6 h-6 flex items-center justify-center bg-purple-100 text-purple-700 rounded-full text-sm font-medium mr-3">
                      {index + 1}
                    </span>
                    <div>
                      <p className="font-medium text-gray-900">{service.name}</p>
                      <p className="text-sm text-gray-500">{service.booking_count} bookings</p>
                    </div>
                  </div>
                  <p className="font-semibold text-green-600">
                    ₹{service.total_revenue.toLocaleString('en-IN')}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Vendor Activity Status */}
      <div className="bg-white p-6 rounded-lg border border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Vendor Activity Status</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {vendorActivity.map((activity) => (
            <div key={activity.status} className="p-4 bg-gray-50 rounded-lg text-center">
              <p className="text-2xl font-bold text-gray-900">{activity.count}</p>
              <p className="text-sm text-gray-600">{activity.status}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <QuickActionCard
          title="Orders"
          href="/dashboard/orders"
          subtitle="View and manage orders"
          icon={ShoppingBag}
        />
        <QuickActionCard
          title="Reviews & Feedback"
          href="/dashboard/reviews"
          subtitle="Customer reviews and ratings"
          icon={Star}
        />
        <QuickActionCard
          title="Services"
          href="/dashboard/services"
          subtitle="All catalog services"
          icon={Settings}
        />
        <QuickActionCard
          title="Vendors"
          href="/dashboard/vendors"
          subtitle="Vendor profiles and status"
          icon={Store}
        />
        <QuickActionCard
          title="Users"
          href="/dashboard/users"
          subtitle="User profiles and activity"
          icon={Users}
        />
        <QuickActionCard
          title="Marketing & Promotions"
          href="/dashboard/marketing"
          subtitle="Banners and campaigns"
          icon={Megaphone}
        />
      </div>
    </div>
  )
}

function StatCard({ 
  title, 
  value, 
  icon: Icon, 
  color,
  highlight = false
}: { 
  title: string
  value: string
  icon: any
  color: 'blue' | 'green' | 'purple' | 'yellow' | 'red'
  highlight?: boolean
}) {
  const colorClasses = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    purple: 'bg-purple-50 text-purple-600',
    yellow: 'bg-yellow-50 text-yellow-600',
    red: 'bg-red-50 text-red-600',
  }

  return (
    <div className={`bg-white p-6 rounded-lg border ${highlight ? 'border-yellow-400 ring-2 ring-yellow-100' : 'border-gray-200'}`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900">{value}</p>
        </div>
        <div className={`p-3 rounded-full ${colorClasses[color]}`}>
          <Icon className="h-6 w-6" />
        </div>
      </div>
    </div>
  )
}

function QuickActionCard({ 
  title, 
  subtitle, 
  href, 
  icon: Icon 
}: { 
  title: string
  subtitle: string
  href: string
  icon: any
}) {
  return (
    <Link href={href} className="block">
      <div className="bg-white p-6 rounded-lg border border-gray-200 hover:shadow-md transition-shadow">
        <div className="flex items-center">
          <div className="p-3 bg-gray-50 rounded-lg">
            <Icon className="h-6 w-6 text-gray-600" />
          </div>
          <div className="ml-4">
            <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
            <p className="text-sm text-gray-600">{subtitle}</p>
          </div>
        </div>
      </div>
    </Link>
  )
}
