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

export interface WithdrawalRequestRow {
  id: string
  vendor_id: string
  wallet_id: string
  amount: number
  status: string
  requested_at: string
  processed_at: string | null
  rejection_reason?: string | null
  bank_snapshot?: any
}

export interface WalletTransactionRow {
  id: string
  vendor_id: string
  txn_type: 'credit' | 'debit'
  source: string
  amount: number
  balance_after: number
  booking_id?: string | null
  milestone_id?: string | null
  escrow_transaction_id?: string | null
  notes?: string | null
  created_at: string
}

export async function getDashboardStats(): Promise<DashboardStats> {
  const supabase = createClient()
  
  // Use database aggregations instead of fetching all data
  // Run queries in parallel for better performance
  const [
    { count: totalOrders },
    { count: pendingApproval },
    { count: cancelledOrders },
    { count: completedOrders },
    { count: vendorCount },
    { count: userCount },
    { data: revenueData },
    { data: monthlyActiveUsers },
    { data: yearlyActiveUsers }
  ] = await Promise.all([
    // Total orders count
    supabase.from('bookings').select('*', { count: 'exact', head: true }),
    // Pending orders count
    supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    // Cancelled orders count
    supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('status', 'cancelled'),
    // Completed orders count
    supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('status', 'completed'),
    // Vendor count
    supabase.from('vendor_profiles').select('*', { count: 'exact', head: true }),
    // User count
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    // Total revenue (sum of non-cancelled bookings) - use a more efficient approach
    // Instead of fetching all, we can use RPC or limit to recent bookings for approximation
    // For now, limit to last 1000 bookings for performance
    supabase.from('bookings').select('amount').neq('status', 'cancelled').order('created_at', { ascending: false }).limit(1000),
    // Monthly active users (distinct user_ids in last 30 days)
    supabase.from('bookings').select('user_id').gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()),
    // Yearly active users (distinct user_ids in last year)
    supabase.from('bookings').select('user_id').gte('created_at', new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString())
  ])
  
  // Calculate revenue from fetched amounts
  const totalRevenue = (revenueData || []).reduce((sum, b) => sum + (Number(b.amount) || 0), 0)
  const averageOrderValue = (totalOrders || 0) > 0 ? totalRevenue / (totalOrders || 1) : 0
  
  // Get unique user counts
  const activeUsersMonthly = new Set((monthlyActiveUsers || []).map(b => b.user_id).filter(Boolean)).size
  const activeUsersYearly = new Set((yearlyActiveUsers || []).map(b => b.user_id).filter(Boolean)).size
  
  return {
    totalOrders: totalOrders || 0,
    pendingApproval: pendingApproval || 0,
    cancelledOrders: cancelledOrders || 0,
    completedOrders: completedOrders || 0,
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
  
  // Use database aggregation with RPC or optimized query
  // For now, use a more efficient approach: fetch only needed fields and limit results
  const { data: bookings } = await supabase
    .from('bookings')
    .select('vendor_id, amount, vendor_profiles!inner(id, business_name)')
    .neq('status', 'cancelled')
    .limit(1000) // Reasonable limit instead of fetching all
  
  if (!bookings || bookings.length === 0) return []
  
  // Aggregate by vendor (more efficient with limited data)
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

// ---------------- Wallet / Withdrawals (admin) ----------------

export async function listWithdrawalRequests(status: string[] = ['pending']): Promise<WithdrawalRequestRow[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from('withdrawal_requests')
    .select('*')
    .in('status', status)
    .order('requested_at', { ascending: false })

  if (error) {
    console.error('Error fetching withdrawal requests:', error)
    return []
  }
  return data || []
}

export async function approveWithdrawalRequest(requestId: string, adminId?: string) {
  const supabase = createClient()

  // Fetch request + wallet
  const { data: req, error: reqErr } = await supabase
    .from('withdrawal_requests')
    .select('*')
    .eq('id', requestId)
    .maybeSingle()
  if (reqErr || !req) throw new Error(reqErr?.message || 'Request not found')
  if (req.status !== 'pending') throw new Error('Only pending requests can be approved')

  // Fetch wallet
  const { data: wallet, error: wErr } = await supabase
    .from('vendor_wallets')
    .select('*')
    .eq('id', req.wallet_id)
    .maybeSingle()
  if (wErr || !wallet) throw new Error(wErr?.message || 'Wallet not found')

  const newBalance = Number(wallet.balance) - Number(req.amount)
  const newPending = Number(wallet.pending_withdrawal) - Number(req.amount)
  if (newBalance < 0 || newPending < 0) throw new Error('Insufficient balance')

  // Update wallet balances
  const { error: uwErr } = await supabase
    .from('vendor_wallets')
    .update({
      balance: newBalance,
      pending_withdrawal: newPending,
      updated_at: new Date().toISOString(),
    })
    .eq('id', wallet.id)
  if (uwErr) throw new Error(uwErr.message)

  // Insert wallet transaction (debit)
  const { data: txn, error: txnErr } = await supabase
    .from('wallet_transactions')
    .insert({
      wallet_id: wallet.id,
      vendor_id: req.vendor_id,
      txn_type: 'debit',
      source: 'withdrawal',
      amount: req.amount,
      balance_after: newBalance,
      notes: 'Withdrawal approved by admin',
    })
    .select()
    .maybeSingle()
  if (txnErr) throw new Error(txnErr.message)

  // Update request status
  const { error: uReqErr } = await supabase
    .from('withdrawal_requests')
    .update({
      status: 'approved',
      admin_id: adminId,
      processed_at: new Date().toISOString(),
    })
    .eq('id', requestId)
  if (uReqErr) throw new Error(uReqErr.message)

  return { walletBalance: newBalance, transaction: txn }
}

export async function rejectWithdrawalRequest(requestId: string, reason = 'Rejected by admin', adminId?: string) {
  const supabase = createClient()

  const { data: req, error: reqErr } = await supabase
    .from('withdrawal_requests')
    .select('*')
    .eq('id', requestId)
    .maybeSingle()
  if (reqErr || !req) throw new Error(reqErr?.message || 'Request not found')
  if (req.status !== 'pending') throw new Error('Only pending requests can be rejected')

  // Release pending_withdrawal
  const { data: wallet } = await supabase
    .from('vendor_wallets')
    .select('*')
    .eq('id', req.wallet_id)
    .maybeSingle()
  if (wallet) {
    const newPending = Number(wallet.pending_withdrawal) - Number(req.amount)
    await supabase
      .from('vendor_wallets')
      .update({
        pending_withdrawal: newPending < 0 ? 0 : newPending,
        updated_at: new Date().toISOString(),
      })
      .eq('id', wallet.id)
  }

  const { error: uReqErr } = await supabase
    .from('withdrawal_requests')
    .update({
      status: 'rejected',
      admin_id: adminId,
      rejection_reason: reason,
      processed_at: new Date().toISOString(),
    })
    .eq('id', requestId)
  if (uReqErr) throw new Error(uReqErr.message)
}

export async function creditVendorWalletFromMilestone(milestoneId: string) {
  const supabase = createClient()

  // Fetch milestone + booking to get vendor_id and amount
  const { data: milestone, error: mErr } = await supabase
    .from('payment_milestones')
    .select('id, amount, booking_id')
    .eq('id', milestoneId)
    .maybeSingle()
  if (mErr || !milestone) throw new Error(mErr?.message || 'Milestone not found')

  const { data: booking, error: bErr } = await supabase
    .from('bookings')
    .select('id, vendor_id')
    .eq('id', milestone.booking_id)
    .maybeSingle()
  if (bErr || !booking) throw new Error(bErr?.message || 'Booking not found')

  // Ensure wallet
  let wallet
  const { data: newWallet, error: insertErr } = await supabase
    .from('vendor_wallets')
    .insert({ vendor_id: booking.vendor_id })
    .select()
    .maybeSingle()

  if (insertErr) {
    // Wallet might already exist, try to fetch it
    const { data: existingWallet, error: fetchErr } = await supabase
      .from('vendor_wallets')
      .select('*')
      .eq('vendor_id', booking.vendor_id)
      .maybeSingle()
    
    if (fetchErr || !existingWallet) {
      throw new Error(fetchErr?.message || 'Failed to get or create wallet')
    }
    wallet = existingWallet
  } else {
    wallet = newWallet
  }

  if (!wallet) throw new Error('Wallet not found/created')

  const newBalance = Number(wallet.balance) + Number(milestone.amount)
  const newTotal = Number(wallet.total_earned) + Number(milestone.amount)

  const { error: uwErr } = await supabase
    .from('vendor_wallets')
    .update({
      balance: newBalance,
      total_earned: newTotal,
      updated_at: new Date().toISOString(),
    })
    .eq('id', wallet.id)
  if (uwErr) throw new Error(uwErr.message)

  const { data: txn, error: txnErr } = await supabase
    .from('wallet_transactions')
    .insert({
      wallet_id: wallet.id,
      vendor_id: booking.vendor_id,
      txn_type: 'credit',
      source: 'milestone_release',
      amount: milestone.amount,
      balance_after: newBalance,
      booking_id: booking.id,
      milestone_id: milestone.id,
      notes: 'Milestone released to vendor wallet',
    })
    .select()
    .maybeSingle()
  if (txnErr) throw new Error(txnErr.message)

  return txn as WalletTransactionRow
}

export async function getPopularServices(limit = 5): Promise<PopularService[]> {
  const supabase = createClient()
  
  // Use a more efficient approach: limit data fetched
  const { data: bookings } = await supabase
    .from('bookings')
    .select('service_id, amount, services!inner(id, name)')
    .neq('status', 'cancelled')
    .limit(1000) // Reasonable limit instead of fetching all
  
  if (!bookings || bookings.length === 0) return []
  
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

