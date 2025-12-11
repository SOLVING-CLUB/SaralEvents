// Dashboard data queries for Supabase
import { createClient } from './supabase'

export interface DashboardStats {
  totalOrders: number
  pendingApproval: number
  cancelledOrders: number
  completedOrders: number
  totalRevenue: number
  averageOrderValue: number
  activeVendors: number
  totalUsers: number
  activeUsersMonthly: number
  activeUsersYearly: number
}

export interface TopVendor {
  id: string
  business_name: string
  total_orders: number
  total_revenue: number
}

export interface PopularService {
  id: string
  name: string
  booking_count: number
  total_revenue: number
}

export interface VendorActivity {
  status: string
  count: number
}

export async function getDashboardStats(): Promise<DashboardStats> {
  const supabase = createClient()
  
  // Get all bookings for calculations
  const { data: bookings, error: bookingsError } = await supabase
    .from('bookings')
    .select('id, status, amount, created_at')
  
  if (bookingsError) {
    console.error('Error fetching bookings:', bookingsError)
  }
  
  const allBookings = bookings || []
  
  const totalOrders = allBookings.length
  const pendingApproval = allBookings.filter(b => b.status?.toLowerCase() === 'pending').length
  const cancelledOrders = allBookings.filter(b => b.status?.toLowerCase() === 'cancelled').length
  const completedOrders = allBookings.filter(b => b.status?.toLowerCase() === 'completed').length
  
  const totalRevenue = allBookings
    .filter(b => b.status?.toLowerCase() !== 'cancelled')
    .reduce((sum, b) => sum + (Number(b.amount) || 0), 0)
  
  const averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0
  
  // Get vendor count
  const { count: vendorCount } = await supabase
    .from('vendor_profiles')
    .select('*', { count: 'exact', head: true })
  
  // Get user count
  const { count: userCount } = await supabase
    .from('profiles')
    .select('*', { count: 'exact', head: true })
  
  // Get active users (monthly) - users who created bookings in last 30 days
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
  
  const { data: monthlyActiveBookings } = await supabase
    .from('bookings')
    .select('user_id')
    .gte('created_at', thirtyDaysAgo.toISOString())
  
  const activeUsersMonthly = new Set(monthlyActiveBookings?.map(b => b.user_id) || []).size
  
  // Get active users (yearly)
  const oneYearAgo = new Date()
  oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1)
  
  const { data: yearlyActiveBookings } = await supabase
    .from('bookings')
    .select('user_id')
    .gte('created_at', oneYearAgo.toISOString())
  
  const activeUsersYearly = new Set(yearlyActiveBookings?.map(b => b.user_id) || []).size
  
  return {
    totalOrders,
    pendingApproval,
    cancelledOrders,
    completedOrders,
    totalRevenue,
    averageOrderValue,
    activeVendors: vendorCount || 0,
    totalUsers: userCount || 0,
    activeUsersMonthly,
    activeUsersYearly,
  }
}

export async function getTopVendors(limit = 5): Promise<TopVendor[]> {
  const supabase = createClient()
  
  // Get all bookings with vendor info
  const { data: bookings } = await supabase
    .from('bookings')
    .select('vendor_id, amount, status, vendor_profiles(id, business_name)')
    .neq('status', 'cancelled')
  
  if (!bookings) return []
  
  // Aggregate by vendor
  const vendorMap = new Map<string, { business_name: string; total_orders: number; total_revenue: number }>()
  
  for (const booking of bookings) {
    const vendorId = booking.vendor_id
    const vendorProfile = booking.vendor_profiles as any
    if (!vendorId || !vendorProfile) continue
    
    const existing = vendorMap.get(vendorId) || {
      business_name: vendorProfile.business_name || 'Unknown',
      total_orders: 0,
      total_revenue: 0,
    }
    
    existing.total_orders += 1
    existing.total_revenue += Number(booking.amount) || 0
    vendorMap.set(vendorId, existing)
  }
  
  // Convert to array and sort by revenue
  const vendors: TopVendor[] = Array.from(vendorMap.entries())
    .map(([id, data]) => ({ id, ...data }))
    .sort((a, b) => b.total_revenue - a.total_revenue)
    .slice(0, limit)
  
  return vendors
}

export async function getPopularServices(limit = 5): Promise<PopularService[]> {
  const supabase = createClient()
  
  // Get all bookings with service info
  const { data: bookings } = await supabase
    .from('bookings')
    .select('service_id, amount, status, services(id, name)')
    .neq('status', 'cancelled')
  
  if (!bookings) return []
  
  // Aggregate by service
  const serviceMap = new Map<string, { name: string; booking_count: number; total_revenue: number }>()
  
  for (const booking of bookings) {
    const serviceId = booking.service_id
    const service = booking.services as any
    if (!serviceId || !service) continue
    
    const existing = serviceMap.get(serviceId) || {
      name: service.name || 'Unknown',
      booking_count: 0,
      total_revenue: 0,
    }
    
    existing.booking_count += 1
    existing.total_revenue += Number(booking.amount) || 0
    serviceMap.set(serviceId, existing)
  }
  
  // Convert to array and sort by booking count
  const services: PopularService[] = Array.from(serviceMap.entries())
    .map(([id, data]) => ({ id, ...data }))
    .sort((a, b) => b.booking_count - a.booking_count)
    .slice(0, limit)
  
  return services
}

export async function getVendorActivityStatus(): Promise<VendorActivity[]> {
  const supabase = createClient()
  
  const { data: vendors } = await supabase
    .from('vendor_profiles')
    .select('is_active')
  
  if (!vendors) return []
  
  const active = vendors.filter(v => v.is_active === true).length
  const inactive = vendors.filter(v => v.is_active === false).length
  const pending = vendors.length - active - inactive
  
  return [
    { status: 'Active', count: active },
    { status: 'Inactive', count: inactive },
    { status: 'Pending', count: pending },
  ]
}

export async function getCustomerQueries(): Promise<{ category: string; count: number }[]> {
  const supabase = createClient()
  
  // Check if support_tickets table exists and get data
  const { data: tickets, error } = await supabase
    .from('support_tickets')
    .select('category')
  
  if (error || !tickets) {
    // Return sample categories if table doesn't exist
    return [
      { category: 'General', count: 0 },
      { category: 'Booking', count: 0 },
      { category: 'Payment', count: 0 },
      { category: 'Technical', count: 0 },
    ]
  }
  
  // Aggregate by category
  const categoryMap = new Map<string, number>()
  for (const ticket of tickets) {
    const cat = ticket.category || 'General'
    categoryMap.set(cat, (categoryMap.get(cat) || 0) + 1)
  }
  
  return Array.from(categoryMap.entries())
    .map(([category, count]) => ({ category, count }))
    .sort((a, b) => b.count - a.count)
}

