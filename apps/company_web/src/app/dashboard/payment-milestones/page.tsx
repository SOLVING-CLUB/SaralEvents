"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { 
  RefreshCw, 
  CheckCircle, 
  Clock,
  DollarSign,
  TrendingUp,
  Shield,
  AlertCircle,
  FileText
} from 'lucide-react'

type PaymentMilestone = {
  id: string
  booking_id: string
  milestone_type: 'advance' | 'arrival' | 'completion'
  percentage: number
  amount: number
  status: 'pending' | 'paid' | 'held_in_escrow' | 'released' | 'refunded'
  escrow_held_at: string | null
  escrow_released_at: string | null
  created_at: string
  updated_at: string
  bookings?: {
    id: string
    amount: number
    booking_date: string
    status: string
    vendor_profiles?: {
      business_name: string
      id: string
    } | null
    services?: {
      name: string
      categories?: {
        name: string
      } | null
    } | null
  } | null
  escrow_transactions?: Array<{
    id: string
    transaction_type: string
    amount: number
    commission_amount: number
    vendor_amount: number
    status: string
    admin_verified_at: string | null
    admin_verified_by: string | null
  }>
}

// Business rules:
// - 20% advance and 50% arrival payments are fully released to vendor wallet (no commission)
// - Final 30% completion payment is split: 10% of TOTAL order amount as company commission,
//   remaining 20% of TOTAL order amount is released to vendor wallet.
const COMMISSION_RATE = 0.10 // 10% of total amount (applied only on completion milestone)
const PAYMENT_GATEWAY_FEE_RATE = 0.0 // Gateway fee not deducted at milestone release level

export default function PaymentMilestonesPage() {
  const supabase = createClient()
  const [milestones, setMilestones] = useState<PaymentMilestone[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('held_in_escrow')
  const [processingId, setProcessingId] = useState<string | null>(null)

  useEffect(() => {
    loadData()
  }, [statusFilter])

  async function loadData() {
    setLoading(true)
    setError(null)
    
    try {
      let query = supabase
        .from('payment_milestones')
        .select(`
          *,
          bookings!inner(
            id,
            amount,
            booking_date,
            status,
            vendor_profiles(business_name, id),
            services(name, categories(name))
          ),
          escrow_transactions(*)
        `)
        .order('created_at', { ascending: false })
        .limit(200)

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter)
      }

      const { data, error: err } = await query

      if (err) throw err

      const transformed = (data || []).map((m: any) => ({
        ...m,
        bookings: Array.isArray(m.bookings) ? m.bookings[0] : m.bookings,
        escrow_transactions: m.escrow_transactions || []
      })) as PaymentMilestone[]

      setMilestones(transformed)
    } catch (err: any) {
      setError(err.message)
    }
    setLoading(false)
  }

  async function releaseMilestone(milestoneId: string) {
    // Get milestone first to verify it's completion type
    const { data: milestoneCheck, error: checkErr } = await supabase
      .from('payment_milestones')
      .select('milestone_type')
      .eq('id', milestoneId)
      .maybeSingle()

    if (checkErr || !milestoneCheck) {
      alert('Error: Milestone not found')
      return
    }

    if (milestoneCheck.milestone_type !== 'completion') {
      alert('Error: Only completion (30%) milestones can be released manually. Advance and arrival milestones are automatically released.')
      return
    }

    if (!confirm('Release final payment? This will take 10% commission and release 20% to vendor wallet.')) {
      return
    }

    setProcessingId(milestoneId)
    try {
      // Get milestone details
      const { data: milestone, error: mErr } = await supabase
        .from('payment_milestones')
        .select('*, bookings!inner(vendor_id, amount, vendor_profiles(id))')
        .eq('id', milestoneId)
        .maybeSingle()

      if (mErr || !milestone) throw new Error(mErr?.message || 'Milestone not found')

      const booking = milestone.bookings as any
      const vendorId = booking.vendor_id
      const totalAmount = Number(booking.amount)   // full booking amount

      // For completion milestone: 10% commission, 20% to vendor
      const commissionAmount = totalAmount * COMMISSION_RATE        // 10% of total
      const vendorAmount = totalAmount * 0.20                       // 20% of total
      const grossAmount = Number(milestone.amount) // milestone's 30% amount (for record)

      // Create escrow transaction record
      const { data: escrowTxn, error: etErr } = await supabase
        .from('escrow_transactions')
        .insert({
          booking_id: milestone.booking_id,
          milestone_id: milestoneId,
          transaction_type: 'commission_deduct',
          amount: grossAmount,
          commission_amount: commissionAmount,
          vendor_amount: vendorAmount,
          status: 'completed',
          admin_verified_at: new Date().toISOString(),
          notes: `Commission: ₹${commissionAmount.toFixed(2)}, Vendor Amount: ₹${vendorAmount.toFixed(2)}`
        })
        .select()
        .maybeSingle()

      if (etErr) throw new Error(etErr.message)

      // Update milestone status
      const { error: mUpdateErr } = await supabase
        .from('payment_milestones')
        .update({
          status: 'released',
          escrow_released_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', milestoneId)

      if (mUpdateErr) throw new Error(mUpdateErr.message)

      // Get or create vendor wallet
      let wallet
      const { data: newWallet, error: insertErr } = await supabase
        .from('vendor_wallets')
        .insert({ vendor_id: vendorId })
        .select()
        .maybeSingle()

      if (insertErr) {
        // Wallet might already exist, try to fetch it
        const { data: existingWallet, error: fetchErr } = await supabase
          .from('vendor_wallets')
          .select('*')
          .eq('vendor_id', vendorId)
          .maybeSingle()
        
        if (fetchErr || !existingWallet) {
          throw new Error(fetchErr?.message || 'Failed to get or create wallet')
        }
        wallet = existingWallet
      } else {
        wallet = newWallet
      }

      if (!wallet) throw new Error('Wallet not found/created')

      const newBalance = Number(wallet.balance) + vendorAmount
      const newTotal = Number(wallet.total_earned) + vendorAmount

      // Update wallet
      const { error: wErr } = await supabase
        .from('vendor_wallets')
        .update({
          balance: newBalance,
          total_earned: newTotal,
          updated_at: new Date().toISOString()
        })
        .eq('id', wallet.id)

      if (wErr) throw new Error(wErr.message)

      // Create wallet transaction
      const { error: txnErr } = await supabase
        .from('wallet_transactions')
        .insert({
          wallet_id: wallet.id,
          vendor_id: vendorId,
          txn_type: 'credit',
          source: 'milestone_release',
          amount: vendorAmount,
          balance_after: newBalance,
          booking_id: milestone.booking_id,
          milestone_id: milestoneId,
          escrow_transaction_id: escrowTxn?.id,
          notes: `Milestone released. Gross milestone: ₹${grossAmount.toFixed(2)}, Commission (on total): ₹${commissionAmount.toFixed(2)}, Vendor Net: ₹${vendorAmount.toFixed(2)}`
        })

      if (txnErr) throw new Error(txnErr.message)

      // Update escrow transaction with wallet transaction ID
      if (escrowTxn) {
        await supabase
          .from('escrow_transactions')
          .update({
            vendor_wallet_credited: true,
            updated_at: new Date().toISOString()
          })
          .eq('id', escrowTxn.id)
      }

      alert('Milestone released successfully!')
      await loadData()
    } catch (err: any) {
      alert(`Error: ${err.message}`)
    } finally {
      setProcessingId(null)
    }
  }

  const filteredMilestones = milestones.filter(m => {
    if (search) {
      const q = search.toLowerCase()
      return m.bookings?.vendor_profiles?.business_name?.toLowerCase().includes(q) ||
             m.bookings?.services?.name?.toLowerCase().includes(q) ||
             m.booking_id.toLowerCase().includes(q)
    }
    return true
  })

  // Group milestones by type
  const advanceMilestones = filteredMilestones.filter(m => m.milestone_type === 'advance')
  const arrivalMilestones = filteredMilestones.filter(m => m.milestone_type === 'arrival')
  const completionMilestones = filteredMilestones.filter(m => m.milestone_type === 'completion')

  const stats = {
    totalHeld: milestones.filter(m => m.status === 'held_in_escrow').length,
    totalHeldAmount: milestones
      .filter(m => m.status === 'held_in_escrow')
      .reduce((sum, m) => sum + Number(m.amount), 0),
    totalReleased: milestones.filter(m => m.status === 'released').length,
    totalReleasedAmount: milestones
      .filter(m => m.status === 'released')
      .reduce((sum, m) => sum + Number(m.amount), 0),
  }

  const getMilestoneLabel = (type: string) => {
    switch (type) {
      case 'advance': return 'Advance (20%)'
      case 'arrival': return 'Arrival (50%)'
      case 'completion': return 'Completion (30%)'
      default: return type
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'held_in_escrow': return 'bg-yellow-100 text-yellow-700'
      case 'released': return 'bg-green-100 text-green-700'
      case 'paid': return 'bg-blue-100 text-blue-700'
      case 'pending': return 'bg-gray-100 text-gray-700'
      case 'refunded': return 'bg-red-100 text-red-700'
      default: return 'bg-gray-100 text-gray-700'
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Payment Milestones & Escrow</h1>
          <p className="text-gray-600">Manage payment milestones and release funds to vendor wallets</p>
        </div>
        <Button onClick={loadData} disabled={loading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-lg border border-yellow-200 bg-yellow-50/30">
          <div className="flex items-center">
            <Shield className="h-8 w-8 text-yellow-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Held in Escrow</p>
              <p className="text-2xl font-bold text-yellow-600">{stats.totalHeld}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-yellow-200 bg-yellow-50/30">
          <div className="flex items-center">
            <DollarSign className="h-8 w-8 text-yellow-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Escrow Amount</p>
              <p className="text-2xl font-bold text-yellow-600">₹{stats.totalHeldAmount.toFixed(2)}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-green-200 bg-green-50/30">
          <div className="flex items-center">
            <CheckCircle className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Released</p>
              <p className="text-2xl font-bold text-green-600">{stats.totalReleased}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-green-200 bg-green-50/30">
          <div className="flex items-center">
            <TrendingUp className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Released Amount</p>
              <p className="text-2xl font-bold text-green-600">₹{stats.totalReleasedAmount.toFixed(2)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg border p-4">
        <div className="flex gap-4">
          <div className="flex-1">
            <Input
              placeholder="Search by vendor, service, or booking ID..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <select
            className="h-10 rounded-md border border-input bg-background px-3 text-sm"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="all">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="paid">Paid</option>
            <option value="held_in_escrow">Held in Escrow</option>
            <option value="released">Released</option>
            <option value="refunded">Refunded</option>
          </select>
        </div>
      </div>

      {/* Milestones Sections */}
      <div className="space-y-6">
        {/* Initial Payment (20%) Section */}
        <div className="bg-white rounded-lg border">
          <div className="p-4 border-b bg-blue-50">
            <h2 className="text-lg font-semibold text-gray-900 flex items-center">
              <Shield className="h-5 w-5 mr-2 text-blue-600" />
              Initial Payment (20% Advance)
            </h2>
            <p className="text-sm text-gray-600 mt-1">
              Automatically released to vendor wallet when 50% arrival payment is made
            </p>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="p-3 text-left">Booking</th>
                  <th className="p-3 text-left">Vendor</th>
                  <th className="p-3 text-right">Amount</th>
                  <th className="p-3 text-left">Status</th>
                  <th className="p-3 text-left">Held Since</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {loading ? (
                  <tr><td colSpan={5} className="p-8 text-center">Loading...</td></tr>
                ) : advanceMilestones.length === 0 ? (
                  <tr><td colSpan={5} className="p-8 text-center text-gray-500">No advance payments found</td></tr>
                ) : advanceMilestones.map(m => {
                  const booking = m.bookings
                  const vendorName = booking?.vendor_profiles?.business_name || 'Unknown'
                  const serviceName = booking?.services?.name || 'Unknown'
                  const grossAmount = Number(m.amount)
                  const isReleased = m.status === 'released'

                  return (
                    <tr key={m.id} className="hover:bg-gray-50">
                      <td className="p-3">
                        <div>
                          <p className="font-medium">{serviceName}</p>
                          <p className="text-xs text-gray-400 font-mono">{m.booking_id.slice(0, 8)}...</p>
                        </div>
                      </td>
                      <td className="p-3">
                        <p className="font-medium">{vendorName}</p>
                      </td>
                      <td className="p-3 text-right">
                        <p className="font-bold text-green-600">₹{grossAmount.toFixed(2)}</p>
                      </td>
                      <td className="p-3">
                        <span className={`px-2 py-1 rounded text-xs ${getStatusColor(m.status)}`}>
                          {m.status.replace('_', ' ').toUpperCase()}
                        </span>
                      </td>
                      <td className="p-3 text-xs text-gray-500">
                        {m.escrow_held_at 
                          ? new Date(m.escrow_held_at).toLocaleDateString()
                          : m.created_at 
                          ? new Date(m.created_at).toLocaleDateString()
                          : 'N/A'}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Arrival Payment (50%) Section */}
        <div className="bg-white rounded-lg border">
          <div className="p-4 border-b bg-green-50">
            <h2 className="text-lg font-semibold text-gray-900 flex items-center">
              <CheckCircle className="h-5 w-5 mr-2 text-green-600" />
              Arrival Payment (50%)
            </h2>
            <p className="text-sm text-gray-600 mt-1">
              Automatically released to vendor wallet when final 30% completion payment is made
            </p>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="p-3 text-left">Booking</th>
                  <th className="p-3 text-left">Vendor</th>
                  <th className="p-3 text-right">Amount</th>
                  <th className="p-3 text-left">Status</th>
                  <th className="p-3 text-left">Held Since</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {loading ? (
                  <tr><td colSpan={5} className="p-8 text-center">Loading...</td></tr>
                ) : arrivalMilestones.length === 0 ? (
                  <tr><td colSpan={5} className="p-8 text-center text-gray-500">No arrival payments found</td></tr>
                ) : arrivalMilestones.map(m => {
                  const booking = m.bookings
                  const vendorName = booking?.vendor_profiles?.business_name || 'Unknown'
                  const serviceName = booking?.services?.name || 'Unknown'
                  const grossAmount = Number(m.amount)
                  const isReleased = m.status === 'released'

                  return (
                    <tr key={m.id} className="hover:bg-gray-50">
                      <td className="p-3">
                        <div>
                          <p className="font-medium">{serviceName}</p>
                          <p className="text-xs text-gray-400 font-mono">{m.booking_id.slice(0, 8)}...</p>
                        </div>
                      </td>
                      <td className="p-3">
                        <p className="font-medium">{vendorName}</p>
                      </td>
                      <td className="p-3 text-right">
                        <p className="font-bold text-green-600">₹{grossAmount.toFixed(2)}</p>
                      </td>
                      <td className="p-3">
                        <span className={`px-2 py-1 rounded text-xs ${getStatusColor(m.status)}`}>
                          {m.status.replace('_', ' ').toUpperCase()}
                        </span>
                      </td>
                      <td className="p-3 text-xs text-gray-500">
                        {m.escrow_held_at 
                          ? new Date(m.escrow_held_at).toLocaleDateString()
                          : m.created_at 
                          ? new Date(m.created_at).toLocaleDateString()
                          : 'N/A'}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Final Payment (30%) Section - Only this can be released */}
        <div className="bg-white rounded-lg border border-yellow-300">
          <div className="p-4 border-b bg-yellow-50">
            <h2 className="text-lg font-semibold text-gray-900 flex items-center">
              <DollarSign className="h-5 w-5 mr-2 text-yellow-600" />
              Final Payment (30% Completion) - Admin Release Required
            </h2>
            <p className="text-sm text-gray-600 mt-1">
              Release funds: 10% commission to company, 20% to vendor wallet
            </p>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  <th className="p-3 text-left">Booking</th>
                  <th className="p-3 text-left">Vendor</th>
                  <th className="p-3 text-right">Amount</th>
                  <th className="p-3 text-left">Status</th>
                  <th className="p-3 text-left">Held Since</th>
                  <th className="p-3 text-left">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {loading ? (
                  <tr><td colSpan={6} className="p-8 text-center">Loading...</td></tr>
                ) : error ? (
                  <tr><td colSpan={6} className="p-8 text-center text-red-600">{error}</td></tr>
                ) : completionMilestones.length === 0 ? (
                  <tr><td colSpan={6} className="p-8 text-center text-gray-500">No completion payments found</td></tr>
                ) : completionMilestones.map(m => {
                  const booking = m.bookings
                  const vendorName = booking?.vendor_profiles?.business_name || 'Unknown'
                  const serviceName = booking?.services?.name || 'Unknown'
                  const categoryName = booking?.services?.categories?.name || 'Unknown'
                  const grossAmount = Number(m.amount)
                  const totalAmount = Number(booking?.amount || 0)
                  const commissionAmount = totalAmount * COMMISSION_RATE // 10% of total
                  const vendorAmount = totalAmount * 0.20 // 20% of total
                  const hasEscrowTxn = m.escrow_transactions && m.escrow_transactions.length > 0
                  const isReleased = m.status === 'released'

                  return (
                    <tr key={m.id} className="hover:bg-gray-50">
                      <td className="p-3">
                        <div>
                          <p className="font-medium">{serviceName}</p>
                          <p className="text-xs text-gray-500">{categoryName}</p>
                          <p className="text-xs text-gray-400 font-mono">{m.booking_id.slice(0, 8)}...</p>
                        </div>
                      </td>
                      <td className="p-3">
                        <p className="font-medium">{vendorName}</p>
                      </td>
                      <td className="p-3 text-right">
                        <div>
                          <p className="font-bold text-green-600">₹{grossAmount.toFixed(2)}</p>
                          {isReleased && hasEscrowTxn && (
                            <div className="text-xs text-gray-500 mt-1">
                              <p>Vendor: ₹{vendorAmount.toFixed(2)}</p>
                              <p>Commission: ₹{commissionAmount.toFixed(2)}</p>
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="p-3">
                        <span className={`px-2 py-1 rounded text-xs ${getStatusColor(m.status)}`}>
                          {m.status.replace('_', ' ').toUpperCase()}
                        </span>
                      </td>
                      <td className="p-3 text-xs text-gray-500">
                        {m.escrow_held_at 
                          ? new Date(m.escrow_held_at).toLocaleDateString()
                          : m.created_at 
                          ? new Date(m.created_at).toLocaleDateString()
                          : 'N/A'}
                      </td>
                      <td className="p-3">
                        {m.status === 'held_in_escrow' && (
                          <Button
                            size="sm"
                            onClick={() => releaseMilestone(m.id)}
                            disabled={processingId === m.id}
                            className="bg-yellow-600 hover:bg-yellow-700"
                          >
                            {processingId === m.id ? (
                              <>
                                <RefreshCw className="h-3 w-3 mr-1 animate-spin" />
                                Processing...
                              </>
                            ) : (
                              <>
                                <CheckCircle className="h-3 w-3 mr-1" />
                                Release Funds
                              </>
                            )}
                          </Button>
                        )}
                        {isReleased && (
                          <div className="text-xs text-green-600">
                            <CheckCircle className="h-4 w-4 inline mr-1" />
                            Released
                          </div>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Info Card */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex items-start">
          <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 mr-3" />
          <div className="flex-1">
            <h3 className="font-semibold text-blue-900 mb-2">Payment Structure & Commission</h3>
            <div className="text-sm text-blue-800 space-y-1">
              <p><strong>Payment Milestones:</strong></p>
              <ul className="list-disc list-inside ml-2 space-y-1">
                <li><strong>20% Advance:</strong> Held in escrow, automatically released to vendor when 50% arrival payment is made</li>
                <li><strong>50% Arrival:</strong> Held in escrow, automatically released to vendor when final 30% completion payment is made</li>
                <li><strong>30% Completion:</strong> Held in escrow, requires admin approval for release</li>
              </ul>
              <p className="mt-2"><strong>Admin Release (Final 30% only):</strong></p>
              <ul className="list-disc list-inside ml-2 space-y-1">
                <li>Company Commission: 10% of total booking amount</li>
                <li>Vendor Receives: 20% of total booking amount</li>
                <li>Total Vendor Receives: 20% + 50% + 20% = 90% of total booking amount</li>
                <li>Total Company Receives: 10% of total booking amount</li>
              </ul>
              <p className="mt-2"><strong>Note:</strong> Only completion (30%) milestones can be manually released by admin. Advance and arrival payments are automatically released to vendor wallets at their respective milestones.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
