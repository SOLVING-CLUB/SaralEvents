"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { 
  RefreshCw, 
  DollarSign, 
  XCircle, 
  CheckCircle, 
  Clock,
  AlertCircle,
  FileText
} from 'lucide-react'

type Refund = {
  id: string
  booking_id: string
  cancelled_by: string
  refund_amount: number
  non_refundable_amount: number
  refund_percentage: number
  reason: string
  status: string
  created_at: string
  processed_at: string | null
  processed_by: string | null
  company_amount?: number | null
  vendor_amount?: number | null
  customer_amount?: number | null
  bookings?: {
    booking_date: string
    amount: number
    vendor_id: string
    services?: { name: string } | null
    vendor_profiles?: { business_name: string } | null
  } | null
}

export default function RefundsPage() {
  const supabase = createClient()
  const [refunds, setRefunds] = useState<Refund[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [selectedRefund, setSelectedRefund] = useState<Refund | null>(null)

  useEffect(() => {
    loadRefunds()
  }, [])

  async function loadRefunds() {
    setLoading(true)
    setError(null)
    
    const { data, error } = await supabase
      .from('refunds')
      .select(`
        *,
        bookings!inner(
          booking_date,
          amount,
          vendor_id,
          services(name),
          vendor_profiles(business_name)
        )
      `)
      .order('created_at', { ascending: false })
      .limit(200)
    
    if (error) {
      setError(error.message)
    } else {
      const transformed = (data || []).map((r: any) => ({
        ...r,
        bookings: Array.isArray(r.bookings) ? r.bookings[0] : r.bookings
      })) as Refund[]
      setRefunds(transformed)
    }
    setLoading(false)
  }

  async function updateRefundStatus(refundId: string, newStatus: string) {
    // Get current admin user for processed_by field
    const { data: { user } } = await supabase.auth.getUser()
    const adminUserId = user?.id || null

    const updateData: any = {
      status: newStatus,
      updated_at: new Date().toISOString()
    }

    // Only set processed_at and processed_by when completing the refund
    if (newStatus === 'completed') {
      updateData.processed_at = new Date().toISOString()
      updateData.processed_by = adminUserId
    } else {
      // Clear processed fields if status is changed from completed
      updateData.processed_at = null
      updateData.processed_by = null
    }

    const { error } = await supabase
      .from('refunds')
      .update(updateData)
      .eq('id', refundId)
    
    if (!error) {
      await loadRefunds()
      if (selectedRefund?.id === refundId) {
        setSelectedRefund(prev => prev ? { ...prev, status: newStatus, processed_by: adminUserId, processed_at: updateData.processed_at } : null)
      }
    } else {
      alert(`Error updating refund: ${error.message}`)
    }
  }

  async function releaseRefund(refundId: string) {
    if (!confirm('Are you sure you want to release this refund? This action will mark the refund as completed and notify the customer.')) {
      return
    }

    // Get refund details to calculate split
    const refund = refunds.find(r => r.id === refundId)
    if (!refund) {
      alert('Refund not found')
      return
    }

    // Calculate refund split:
    // - Customer gets: refund_amount (already calculated)
    // - From non_refundable_amount:
    //   - Company gets: 5% of non_refundable_amount
    //   - Vendor gets: 95% of non_refundable_amount
    // - If customer gets 100% refund, company gets nothing (non_refundable = 0)
    const customerAmount = refund.refund_amount
    const nonRefundable = refund.non_refundable_amount
    const companyAmount = nonRefundable > 0 ? nonRefundable * 0.05 : 0
    const vendorAmount = nonRefundable > 0 ? nonRefundable * 0.95 : 0

    // Get current admin user
    const { data: { user } } = await supabase.auth.getUser()
    const adminUserId = user?.id || null

    // Update refund with split amounts and status
    const updateData: any = {
      status: 'completed',
      processed_at: new Date().toISOString(),
      processed_by: adminUserId,
      updated_at: new Date().toISOString(),
      customer_amount: customerAmount,
      company_amount: companyAmount,
      vendor_amount: vendorAmount,
    }

    const { error: refundError } = await supabase
      .from('refunds')
      .update(updateData)
      .eq('id', refundId)

    if (refundError) {
      alert(`Error updating refund: ${refundError.message}`)
      return
    }

    // If vendor should receive amount, credit their wallet
    if (vendorAmount > 0 && refund.bookings?.vendor_id) {
      try {
        // Get or create vendor wallet
        let wallet
        const { data: newWallet, error: insertErr } = await supabase
          .from('vendor_wallets')
          .insert({ vendor_id: refund.bookings.vendor_id })
          .select()
          .maybeSingle()

        if (insertErr) {
          // Wallet might already exist, try to fetch it
          const { data: existingWallet, error: fetchErr } = await supabase
            .from('vendor_wallets')
            .select('*')
            .eq('vendor_id', refund.bookings.vendor_id)
            .maybeSingle()

          if (fetchErr || !existingWallet) {
            console.error('Failed to get or create wallet:', fetchErr?.message)
            // Continue with refund even if wallet update fails
          } else {
            wallet = existingWallet
          }
        } else {
          wallet = newWallet
        }

        if (wallet) {
          const newBalance = Number(wallet.balance) + vendorAmount
          const newTotal = Number(wallet.total_earned || 0) + vendorAmount

          // Update wallet
          await supabase
            .from('vendor_wallets')
            .update({
              balance: newBalance,
              total_earned: newTotal,
              updated_at: new Date().toISOString(),
            })
            .eq('id', wallet.id)

          // Create wallet transaction
          await supabase
            .from('wallet_transactions')
            .insert({
              wallet_id: wallet.id,
              vendor_id: refund.bookings.vendor_id,
              txn_type: 'credit',
              source: 'refund_split',
              amount: vendorAmount,
              balance_after: newBalance,
              booking_id: refund.booking_id,
              notes: `Refund split: 95% of non-refundable amount (₹${nonRefundable.toFixed(2)}) from cancelled booking`,
            })
        }
      } catch (walletError: any) {
        console.error('Error crediting vendor wallet:', walletError)
        // Don't fail the refund if wallet update fails - log and continue
      }
    }

    // Reload refunds to show updated data
    await loadRefunds()
    if (selectedRefund?.id === refundId) {
      setSelectedRefund(prev => prev ? { ...prev, ...updateData } : null)
    }
  }

  const filtered = refunds.filter(r => {
    if (statusFilter !== 'all' && r.status !== statusFilter) return false
    if (search) {
      const q = search.toLowerCase()
      return r.id.toLowerCase().includes(q) || 
             r.booking_id.toLowerCase().includes(q) ||
             (r.bookings?.services?.name || '').toLowerCase().includes(q)
    }
    return true
  })

  const stats = {
    total: refunds.length,
    pending: refunds.filter(r => r.status === 'pending').length,
    processing: refunds.filter(r => r.status === 'processing').length,
    completed: refunds.filter(r => r.status === 'completed').length,
    totalAmount: refunds
      .filter(r => r.status === 'completed' || r.status === 'processing')
      .reduce((sum, r) => sum + r.refund_amount, 0)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Refund Management</h1>
          <p className="text-gray-600">Manage cancellations and refunds</p>
        </div>
        <Button onClick={loadRefunds} disabled={loading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-lg border">
          <div className="flex items-center">
            <FileText className="h-8 w-8 text-blue-500" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Refunds</p>
              <p className="text-2xl font-bold">{stats.total}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-yellow-200 bg-yellow-50/30">
          <div className="flex items-center">
            <Clock className="h-8 w-8 text-yellow-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Pending</p>
              <p className="text-2xl font-bold text-yellow-600">{stats.pending}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-blue-200 bg-blue-50/30">
          <div className="flex items-center">
            <RefreshCw className="h-8 w-8 text-blue-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Processing</p>
              <p className="text-2xl font-bold text-blue-600">{stats.processing}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-green-200 bg-green-50/30">
          <div className="flex items-center">
            <DollarSign className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Refunded</p>
              <p className="text-2xl font-bold text-green-600">₹{stats.totalAmount.toFixed(2)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg border">
        <div className="flex gap-4">
          <div className="flex-1">
            <Input
              placeholder="Search by refund ID, booking ID, or service..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <select
            className="h-10 rounded-md border border-input bg-background px-3 text-sm"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="all">All statuses</option>
            <option value="pending">Pending</option>
            <option value="processing">Processing</option>
            <option value="completed">Completed</option>
            <option value="failed">Failed</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg border overflow-hidden">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50">
            <tr>
              <th className="p-3 text-left">Refund ID</th>
              <th className="p-3 text-left">Booking</th>
              <th className="p-3 text-left">Service</th>
              <th className="p-3 text-left">Cancelled By</th>
              <th className="p-3 text-right">Refund Amount</th>
              <th className="p-3 text-right">Percentage</th>
              <th className="p-3 text-left">Status</th>
              <th className="p-3 text-left">Created</th>
              <th className="p-3 text-left">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {loading ? (
              <tr><td colSpan={9} className="p-8 text-center">Loading...</td></tr>
            ) : error ? (
              <tr><td colSpan={9} className="p-8 text-center text-red-600">{error}</td></tr>
            ) : filtered.length === 0 ? (
              <tr><td colSpan={9} className="p-8 text-center text-gray-500">No refunds found</td></tr>
            ) : filtered.map(r => (
              <tr key={r.id} className="hover:bg-gray-50">
                <td className="p-3 font-mono text-xs">{r.id.slice(0, 8)}...</td>
                <td className="p-3">
                  <div>
                    <p className="font-medium">{r.bookings?.services?.name || '-'}</p>
                    <p className="text-xs text-gray-500">{r.bookings?.booking_date}</p>
                  </div>
                </td>
                <td className="p-3">{r.bookings?.vendor_profiles?.business_name || '-'}</td>
                <td className="p-3">
                  <span className={`px-2 py-1 rounded text-xs ${
                    r.cancelled_by === 'vendor' 
                      ? 'bg-red-100 text-red-700' 
                      : 'bg-blue-100 text-blue-700'
                  }`}>
                    {r.cancelled_by}
                  </span>
                </td>
                <td className="p-3 text-right font-medium text-green-600">
                  ₹{r.refund_amount.toFixed(2)}
                </td>
                <td className="p-3 text-right">{r.refund_percentage.toFixed(1)}%</td>
                <td className="p-3">
                  <StatusBadge status={r.status} />
                </td>
                <td className="p-3 text-xs text-gray-500">
                  {new Date(r.created_at).toLocaleDateString()}
                </td>
                <td className="p-3">
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setSelectedRefund(r)}
                    >
                      View
                    </Button>
                    {r.status === 'pending' && (
                      <Button
                        size="sm"
                        onClick={() => releaseRefund(r.id)}
                        className="bg-green-600 hover:bg-green-700 text-white"
                      >
                        Release Refund
                      </Button>
                    )}
                    {r.status === 'pending' && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => updateRefundStatus(r.id, 'rejected')}
                        className="text-red-600 border-red-600 hover:bg-red-50"
                      >
                        Reject
                      </Button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Refund Detail Modal */}
      {selectedRefund && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-bold">Refund Details</h2>
              <Button variant="outline" onClick={() => setSelectedRefund(null)}>Close</Button>
            </div>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-gray-600">Refund ID</p>
                  <p className="font-mono text-sm">{selectedRefund.id}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Status</p>
                  <StatusBadge status={selectedRefund.status} />
                </div>
                <div>
                  <p className="text-sm text-gray-600">Customer Refund</p>
                  <p className="text-lg font-bold text-green-600">
                    ₹{(selectedRefund.customer_amount ?? selectedRefund.refund_amount).toFixed(2)}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Non-refundable</p>
                  <p className="text-lg font-bold text-gray-600">₹{selectedRefund.non_refundable_amount.toFixed(2)}</p>
                </div>
                {selectedRefund.status === 'completed' && selectedRefund.non_refundable_amount > 0 && (
                  <>
                    <div>
                      <p className="text-sm text-gray-600">Company Amount (5%)</p>
                      <p className="text-lg font-bold text-blue-600">
                        ₹{(selectedRefund.company_amount ?? 0).toFixed(2)}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600">Vendor Amount (95%)</p>
                      <p className="text-lg font-bold text-purple-600">
                        ₹{(selectedRefund.vendor_amount ?? 0).toFixed(2)}
                      </p>
                    </div>
                  </>
                )}
                <div>
                  <p className="text-sm text-gray-600">Reason</p>
                  <p className="text-sm">{selectedRefund.reason}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Cancelled By</p>
                  <p className="text-sm capitalize">{selectedRefund.cancelled_by}</p>
                </div>
              </div>
              {selectedRefund.status === 'completed' && selectedRefund.non_refundable_amount > 0 && (
                <div className="mt-4 p-4 bg-gray-50 rounded-lg">
                  <p className="text-sm font-medium text-gray-700 mb-2">Refund Split Breakdown</p>
                  <div className="space-y-1 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Customer receives:</span>
                      <span className="font-medium text-green-600">
                        ₹{(selectedRefund.customer_amount ?? selectedRefund.refund_amount).toFixed(2)}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Company receives (5%):</span>
                      <span className="font-medium text-blue-600">
                        ₹{(selectedRefund.company_amount ?? 0).toFixed(2)}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Vendor wallet credited (95%):</span>
                      <span className="font-medium text-purple-600">
                        ₹{(selectedRefund.vendor_amount ?? 0).toFixed(2)}
                      </span>
                    </div>
                    <div className="pt-2 mt-2 border-t border-gray-200 flex justify-between font-medium">
                      <span>Total:</span>
                      <span>
                        ₹{(
                          (selectedRefund.customer_amount ?? selectedRefund.refund_amount) +
                          (selectedRefund.company_amount ?? 0) +
                          (selectedRefund.vendor_amount ?? 0)
                        ).toFixed(2)}
                      </span>
                    </div>
                  </div>
                </div>
              )}
              {selectedRefund.status === 'pending' && (
                <div className="pt-4 border-t">
                  <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                    <p className="text-sm font-medium text-yellow-800 mb-1">⚠️ Admin Approval Required</p>
                    <p className="text-xs text-yellow-700">
                      This refund is pending approval. Review the details and release the refund to complete the process. 
                      The customer will be notified once the refund is released.
                    </p>
                  </div>
                  <p className="text-sm font-medium mb-2">Actions</p>
                  <div className="flex gap-2">
                    <Button 
                      onClick={() => releaseRefund(selectedRefund.id)}
                      className="bg-green-600 hover:bg-green-700 text-white"
                    >
                      ✓ Release Refund
                    </Button>
                    <Button 
                      variant="outline" 
                      onClick={() => updateRefundStatus(selectedRefund.id, 'rejected')}
                      className="text-red-600 border-red-600 hover:bg-red-50"
                    >
                      ✗ Reject Refund
                    </Button>
                  </div>
                </div>
              )}
              {selectedRefund.status === 'completed' && selectedRefund.processed_at && (
                <div className="pt-4 border-t">
                  <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                    <p className="text-sm font-medium text-green-800 mb-1">✓ Refund Released</p>
                    <p className="text-xs text-green-700">
                      This refund was released on {new Date(selectedRefund.processed_at).toLocaleString()}
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-700',
    processing: 'bg-blue-100 text-blue-700',
    completed: 'bg-green-100 text-green-700',
    failed: 'bg-red-100 text-red-700',
    rejected: 'bg-gray-100 text-gray-700',
  }
  return (
    <span className={`px-2 py-1 rounded text-xs ${colors[status] || colors.pending}`}>
      {status}
    </span>
  )
}

