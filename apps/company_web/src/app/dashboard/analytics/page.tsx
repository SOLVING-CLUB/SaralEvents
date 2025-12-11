"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { 
  BarChart3, 
  TrendingUp, 
  TrendingDown,
  IndianRupee, 
  ShoppingBag, 
  Users, 
  Store,
  Clock,
  XCircle,
  CheckCircle,
  Activity,
  Calendar,
  MessageSquare
} from 'lucide-react'
import { Button } from '@/components/ui/Button'

interface AnalyticsData {
  // Order metrics
  totalOrders: number
  pendingOrders: number
  cancelledOrders: number
  completedOrders: number
  confirmedOrders: number
  
  // Financial metrics
  totalSales: number
  avgOrderValue: number
  
  // User metrics
  totalUsers: number
  activeUsersMonthly: number
  activeUsersYearly: number
  newUsersThisMonth: number
  
  // Vendor metrics
  totalVendors: number
  activeVendors: number
  inactiveVendors: number
  pendingVendors: number
  
  // Support metrics
  totalQueries: number
  queriesByCategory: { category: string; count: number }[]
  openTickets: number
  resolvedTickets: number
}

export default function AnalyticsPage() {
  const supabase = createClient()
  const [data, setData] = useState<AnalyticsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [dateRange, setDateRange] = useState<'7d' | '30d' | '90d' | '1y' | 'all'>('30d')

  useEffect(() => {
    loadAnalytics()
  }, [dateRange])

  async function loadAnalytics() {
    setLoading(true)
    setError(null)
    
    try {
      // Calculate date range
      let startDate: Date | null = null
      const now = new Date()
      switch (dateRange) {
        case '7d': startDate = new Date(now.setDate(now.getDate() - 7)); break
        case '30d': startDate = new Date(now.setDate(now.getDate() - 30)); break
        case '90d': startDate = new Date(now.setDate(now.getDate() - 90)); break
        case '1y': startDate = new Date(now.setFullYear(now.getFullYear() - 1)); break
        default: startDate = null
      }

      // Fetch bookings
      let bookingsQuery = supabase.from('bookings').select('id, status, amount, created_at, user_id')
      if (startDate) {
        bookingsQuery = bookingsQuery.gte('created_at', startDate.toISOString())
      }
      const { data: bookings } = await bookingsQuery

      const allBookings = bookings || []
      
      // Order metrics
      const totalOrders = allBookings.length
      const pendingOrders = allBookings.filter(b => b.status?.toLowerCase() === 'pending').length
      const cancelledOrders = allBookings.filter(b => b.status?.toLowerCase() === 'cancelled').length
      const completedOrders = allBookings.filter(b => b.status?.toLowerCase() === 'completed').length
      const confirmedOrders = allBookings.filter(b => b.status?.toLowerCase() === 'confirmed').length
      
      // Financial metrics
      const totalSales = allBookings
        .filter(b => b.status?.toLowerCase() !== 'cancelled')
        .reduce((sum, b) => sum + (Number(b.amount) || 0), 0)
      const avgOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0

      // User metrics
      const { count: totalUsers } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true })

      // Monthly active users
      const thirtyDaysAgo = new Date()
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
      const { data: monthlyActiveBookings } = await supabase
        .from('bookings')
        .select('user_id')
        .gte('created_at', thirtyDaysAgo.toISOString())
      const activeUsersMonthly = new Set(monthlyActiveBookings?.map(b => b.user_id) || []).size

      // Yearly active users
      const oneYearAgo = new Date()
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1)
      const { data: yearlyActiveBookings } = await supabase
        .from('bookings')
        .select('user_id')
        .gte('created_at', oneYearAgo.toISOString())
      const activeUsersYearly = new Set(yearlyActiveBookings?.map(b => b.user_id) || []).size

      // New users this month
      const monthStart = new Date()
      monthStart.setDate(1)
      monthStart.setHours(0, 0, 0, 0)
      const { count: newUsersThisMonth } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', monthStart.toISOString())

      // Vendor metrics
      const { data: vendors } = await supabase
        .from('vendor_profiles')
        .select('is_active, status')
      
      const allVendors = vendors || []
      const totalVendors = allVendors.length
      const activeVendors = allVendors.filter(v => v.is_active === true).length
      const inactiveVendors = allVendors.filter(v => v.is_active === false).length
      const pendingVendors = allVendors.filter(v => v.status === 'pending').length

      // Support metrics
      const { data: tickets } = await supabase
        .from('support_tickets')
        .select('category, status')
      
      const allTickets = tickets || []
      const totalQueries = allTickets.length
      const openTickets = allTickets.filter(t => t.status === 'open' || t.status === 'in_progress').length
      const resolvedTickets = allTickets.filter(t => t.status === 'resolved' || t.status === 'closed').length

      // Queries by category
      const categoryMap = new Map<string, number>()
      for (const ticket of allTickets) {
        const cat = ticket.category || 'General'
        categoryMap.set(cat, (categoryMap.get(cat) || 0) + 1)
      }
      const queriesByCategory = Array.from(categoryMap.entries())
        .map(([category, count]) => ({ category, count }))
        .sort((a, b) => b.count - a.count)

      setData({
        totalOrders,
        pendingOrders,
        cancelledOrders,
        completedOrders,
        confirmedOrders,
        totalSales,
        avgOrderValue,
        totalUsers: totalUsers || 0,
        activeUsersMonthly,
        activeUsersYearly,
        newUsersThisMonth: newUsersThisMonth || 0,
        totalVendors,
        activeVendors,
        inactiveVendors,
        pendingVendors,
        totalQueries,
        queriesByCategory,
        openTickets,
        resolvedTickets,
      })
    } catch (err) {
      console.error('Error loading analytics:', err)
      setError('Failed to load analytics data')
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <BarChart3 className="h-7 w-7 text-blue-600" />
            Analytics Dashboard
          </h1>
          <p className="text-gray-600">Comprehensive business metrics and insights</p>
        </div>
        <div className="flex items-center gap-2">
          <select
            className="h-10 rounded-md border border-input bg-background px-3 text-sm"
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value as any)}
          >
            <option value="7d">Last 7 days</option>
            <option value="30d">Last 30 days</option>
            <option value="90d">Last 90 days</option>
            <option value="1y">Last year</option>
            <option value="all">All time</option>
          </select>
          <Button onClick={loadAnalytics} disabled={loading}>
            Refresh
          </Button>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-600">
          {error}
        </div>
      )}

      {/* Order Metrics */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <ShoppingBag className="h-5 w-5" />
          Order Metrics
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <MetricCard
            title="Total Orders"
            value={data?.totalOrders || 0}
            icon={ShoppingBag}
            color="blue"
          />
          <MetricCard
            title="Pending Orders"
            value={data?.pendingOrders || 0}
            icon={Clock}
            color="yellow"
          />
          <MetricCard
            title="Confirmed"
            value={data?.confirmedOrders || 0}
            icon={CheckCircle}
            color="blue"
          />
          <MetricCard
            title="Completed"
            value={data?.completedOrders || 0}
            icon={CheckCircle}
            color="green"
          />
          <MetricCard
            title="Cancelled"
            value={data?.cancelledOrders || 0}
            icon={XCircle}
            color="red"
          />
        </div>
      </div>

      {/* Financial Metrics */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <IndianRupee className="h-5 w-5" />
          Financial Metrics
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="bg-gradient-to-br from-green-500 to-green-600 p-6 rounded-lg text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-green-100 text-sm">Total Sales</p>
                <p className="text-3xl font-bold">
                  ₹{(data?.totalSales || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <IndianRupee className="h-12 w-12 text-green-200" />
            </div>
          </div>
          <div className="bg-gradient-to-br from-purple-500 to-purple-600 p-6 rounded-lg text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-purple-100 text-sm">Average Order Value</p>
                <p className="text-3xl font-bold">
                  ₹{(data?.avgOrderValue || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
              </div>
              <TrendingUp className="h-12 w-12 text-purple-200" />
            </div>
          </div>
        </div>
      </div>

      {/* User Activity Metrics */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Users className="h-5 w-5" />
          User Activity
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <MetricCard
            title="Total Users"
            value={data?.totalUsers || 0}
            icon={Users}
            color="purple"
          />
          <MetricCard
            title="Active (Monthly)"
            value={data?.activeUsersMonthly || 0}
            icon={Activity}
            color="blue"
          />
          <MetricCard
            title="Active (Yearly)"
            value={data?.activeUsersYearly || 0}
            icon={Activity}
            color="green"
          />
          <MetricCard
            title="New This Month"
            value={data?.newUsersThisMonth || 0}
            icon={TrendingUp}
            color="green"
          />
        </div>
      </div>

      {/* Vendor Activity */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Store className="h-5 w-5" />
          Vendor Activity (Status)
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <MetricCard
            title="Total Vendors"
            value={data?.totalVendors || 0}
            icon={Store}
            color="blue"
          />
          <MetricCard
            title="Active Vendors"
            value={data?.activeVendors || 0}
            icon={CheckCircle}
            color="green"
          />
          <MetricCard
            title="Inactive Vendors"
            value={data?.inactiveVendors || 0}
            icon={XCircle}
            color="red"
          />
          <MetricCard
            title="Pending Approval"
            value={data?.pendingVendors || 0}
            icon={Clock}
            color="yellow"
          />
        </div>
      </div>

      {/* Customer Queries by Category */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <MessageSquare className="h-5 w-5" />
          Customer Queries by Category
        </h2>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white p-6 rounded-lg border border-gray-200">
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div className="p-4 bg-blue-50 rounded-lg text-center">
                <p className="text-2xl font-bold text-blue-600">{data?.totalQueries || 0}</p>
                <p className="text-sm text-gray-600">Total Queries</p>
              </div>
              <div className="p-4 bg-red-50 rounded-lg text-center">
                <p className="text-2xl font-bold text-red-600">{data?.openTickets || 0}</p>
                <p className="text-sm text-gray-600">Open Tickets</p>
              </div>
            </div>
            <div className="p-4 bg-green-50 rounded-lg text-center">
              <p className="text-2xl font-bold text-green-600">{data?.resolvedTickets || 0}</p>
              <p className="text-sm text-gray-600">Resolved Tickets</p>
            </div>
          </div>
          
          <div className="bg-white p-6 rounded-lg border border-gray-200">
            <h3 className="font-medium text-gray-900 mb-4">Queries by Category</h3>
            {(data?.queriesByCategory || []).length === 0 ? (
              <p className="text-gray-500 text-sm">No query data available</p>
            ) : (
              <div className="space-y-3">
                {data?.queriesByCategory.map(({ category, count }) => (
                  <div key={category} className="flex items-center justify-between">
                    <span className="text-gray-700">{category}</span>
                    <div className="flex items-center gap-2">
                      <div className="w-32 bg-gray-100 rounded-full h-2">
                        <div 
                          className="bg-blue-500 rounded-full h-2"
                          style={{ 
                            width: `${data?.totalQueries ? (count / data.totalQueries) * 100 : 0}%` 
                          }}
                        />
                      </div>
                      <span className="text-sm font-medium text-gray-600 w-8 text-right">
                        {count}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function MetricCard({ 
  title, 
  value, 
  icon: Icon, 
  color,
  highlight = false
}: { 
  title: string
  value: number
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
    <div className={`bg-white p-5 rounded-lg border ${highlight ? 'border-yellow-400 ring-2 ring-yellow-100' : 'border-gray-200'}`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900">{value.toLocaleString()}</p>
        </div>
        <div className={`p-3 rounded-full ${colorClasses[color]}`}>
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </div>
  )
}

