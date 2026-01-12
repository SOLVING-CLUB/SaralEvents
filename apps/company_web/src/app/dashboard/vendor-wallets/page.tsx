"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { 
  Wallet, 
  RefreshCw, 
  CheckCircle, 
  XCircle, 
  Clock,
  DollarSign,
  TrendingUp
} from 'lucide-react'

type VendorWallet = {
  id: string
  vendor_id: string
  balance: number
  pending_withdrawal: number
  total_earned: number
  vendor_profiles?: {
    business_name: string
    user_id: string
  } | null
}

type WithdrawalRequest = {
  id: string
  vendor_id: string
  amount: number
  status: string
  requested_at: string
  processed_at: string | null
  bank_snapshot: any
  vendor_profiles?: {
    business_name: string
  } | null
}

export default function VendorWalletsPage() {
  const supabase = createClient()
  const [wallets, setWallets] = useState<VendorWallet[]>([])
  const [withdrawals, setWithdrawals] = useState<WithdrawalRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [activeTab, setActiveTab] = useState<'wallets' | 'withdrawals'>('wallets')

  useEffect(() => {
    loadData()
  }, [])

  async function loadData() {
    setLoading(true)
    setError(null)
    
    try {
      // Load wallets
      const { data: walletData, error: walletError } = await supabase
        .from('vendor_wallets')
        .select(`
          *,
          vendor_profiles!inner(business_name, user_id)
        `)
        .order('balance', { ascending: false })
        .limit(200)
      
      if (walletError) throw walletError

      // Load withdrawal requests
      const { data: withdrawalData, error: withdrawalError } = await supabase
        .from('withdrawal_requests')
        .select(`
          *,
          vendor_profiles!inner(business_name)
        `)
        .order('requested_at', { ascending: false })
        .limit(200)
      
      if (withdrawalError) throw withdrawalError

      const transformedWallets = (walletData || []).map((w: any) => ({
        ...w,
        vendor_profiles: Array.isArray(w.vendor_profiles) ? w.vendor_profiles[0] : w.vendor_profiles
      })) as VendorWallet[]

      const transformedWithdrawals = (withdrawalData || []).map((w: any) => ({
        ...w,
        vendor_profiles: Array.isArray(w.vendor_profiles) ? w.vendor_profiles[0] : w.vendor_profiles
      })) as WithdrawalRequest[]

      setWallets(transformedWallets)
      setWithdrawals(transformedWithdrawals)
    } catch (err: any) {
      setError(err.message)
    }
    setLoading(false)
  }

  async function updateWithdrawalStatus(id: string, status: string) {
    const { error } = await supabase
      .from('withdrawal_requests')
      .update({ 
        status,
        processed_at: status === 'paid' || status === 'rejected' ? new Date().toISOString() : null,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
    
    if (!error) {
      await loadData()
    }
  }

  const filteredWallets = wallets.filter(w => {
    if (search) {
      const q = search.toLowerCase()
      return w.vendor_profiles?.business_name?.toLowerCase().includes(q) ||
             w.vendor_id.toLowerCase().includes(q)
    }
    return true
  })

  const filteredWithdrawals = withdrawals.filter(w => {
    if (statusFilter !== 'all' && w.status !== statusFilter) return false
    if (search) {
      const q = search.toLowerCase()
      return w.vendor_profiles?.business_name?.toLowerCase().includes(q) ||
             w.vendor_id.toLowerCase().includes(q) ||
             w.id.toLowerCase().includes(q)
    }
    return true
  })

  const stats = {
    totalWallets: wallets.length,
    totalBalance: wallets.reduce((sum, w) => sum + w.balance, 0),
    pendingWithdrawals: withdrawals.filter(w => w.status === 'pending').length,
    totalPendingAmount: withdrawals
      .filter(w => w.status === 'pending')
      .reduce((sum, w) => sum + w.amount, 0),
    totalEarned: wallets.reduce((sum, w) => sum + w.total_earned, 0)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Vendor Wallets & Withdrawals</h1>
          <p className="text-gray-600">Manage vendor payments and withdrawal requests</p>
        </div>
        <Button onClick={loadData} disabled={loading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-lg border">
          <div className="flex items-center">
            <Wallet className="h-8 w-8 text-blue-500" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Wallets</p>
              <p className="text-2xl font-bold">{stats.totalWallets}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-green-200 bg-green-50/30">
          <div className="flex items-center">
            <DollarSign className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Balance</p>
              <p className="text-2xl font-bold text-green-600">₹{stats.totalBalance.toFixed(2)}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-yellow-200 bg-yellow-50/30">
          <div className="flex items-center">
            <Clock className="h-8 w-8 text-yellow-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Pending Withdrawals</p>
              <p className="text-2xl font-bold text-yellow-600">{stats.pendingWithdrawals}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-purple-200 bg-purple-50/30">
          <div className="flex items-center">
            <TrendingUp className="h-8 w-8 text-purple-600" />
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Earned</p>
              <p className="text-2xl font-bold text-purple-600">₹{stats.totalEarned.toFixed(2)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-lg border">
        <div className="flex border-b">
          <button
            className={`flex-1 px-4 py-3 text-center font-medium ${
              activeTab === 'wallets'
                ? 'border-b-2 border-blue-600 text-blue-600'
                : 'text-gray-600 hover:text-gray-900'
            }`}
            onClick={() => setActiveTab('wallets')}
          >
            Wallets
          </button>
          <button
            className={`flex-1 px-4 py-3 text-center font-medium ${
              activeTab === 'withdrawals'
                ? 'border-b-2 border-blue-600 text-blue-600'
                : 'text-gray-600 hover:text-gray-900'
            }`}
            onClick={() => setActiveTab('withdrawals')}
          >
            Withdrawal Requests
          </button>
        </div>

        <div className="p-4">
          {/* Filters */}
          <div className="mb-4 flex gap-4">
            <div className="flex-1">
              <Input
                placeholder={activeTab === 'wallets' ? 'Search vendors...' : 'Search withdrawal requests...'}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            {activeTab === 'withdrawals' && (
              <select
                className="h-10 rounded-md border border-input bg-background px-3 text-sm"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="all">All statuses</option>
                <option value="pending">Pending</option>
                <option value="approved">Approved</option>
                <option value="processing">Processing</option>
                <option value="paid">Paid</option>
                <option value="rejected">Rejected</option>
                <option value="failed">Failed</option>
              </select>
            )}
          </div>

          {/* Wallets Table */}
          {activeTab === 'wallets' && (
            <div className="overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="p-3 text-left">Vendor</th>
                    <th className="p-3 text-right">Balance</th>
                    <th className="p-3 text-right">Pending Withdrawal</th>
                    <th className="p-3 text-right">Available</th>
                    <th className="p-3 text-right">Total Earned</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {loading ? (
                    <tr><td colSpan={5} className="p-8 text-center">Loading...</td></tr>
                  ) : error ? (
                    <tr><td colSpan={5} className="p-8 text-center text-red-600">{error}</td></tr>
                  ) : filteredWallets.length === 0 ? (
                    <tr><td colSpan={5} className="p-8 text-center text-gray-500">No wallets found</td></tr>
                  ) : filteredWallets.map(w => (
                    <tr key={w.id} className="hover:bg-gray-50">
                      <td className="p-3">
                        <div>
                          <p className="font-medium">{w.vendor_profiles?.business_name || 'Unknown'}</p>
                          <p className="text-xs text-gray-500 font-mono">{w.vendor_id.slice(0, 8)}...</p>
                        </div>
                      </td>
                      <td className="p-3 text-right font-medium">₹{w.balance.toFixed(2)}</td>
                      <td className="p-3 text-right text-yellow-600">₹{w.pending_withdrawal.toFixed(2)}</td>
                      <td className="p-3 text-right text-green-600 font-medium">
                        ₹{(w.balance - w.pending_withdrawal).toFixed(2)}
                      </td>
                      <td className="p-3 text-right text-gray-600">₹{w.total_earned.toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Withdrawals Table */}
          {activeTab === 'withdrawals' && (
            <div className="overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="p-3 text-left">Vendor</th>
                    <th className="p-3 text-right">Amount</th>
                    <th className="p-3 text-left">Bank Details</th>
                    <th className="p-3 text-left">Status</th>
                    <th className="p-3 text-left">Requested</th>
                    <th className="p-3 text-left">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {loading ? (
                    <tr><td colSpan={6} className="p-8 text-center">Loading...</td></tr>
                  ) : error ? (
                    <tr><td colSpan={6} className="p-8 text-center text-red-600">{error}</td></tr>
                  ) : filteredWithdrawals.length === 0 ? (
                    <tr><td colSpan={6} className="p-8 text-center text-gray-500">No withdrawal requests</td></tr>
                  ) : filteredWithdrawals.map(w => (
                    <tr key={w.id} className="hover:bg-gray-50">
                      <td className="p-3">
                        <div>
                          <p className="font-medium">{w.vendor_profiles?.business_name || 'Unknown'}</p>
                          <p className="text-xs text-gray-500 font-mono">{w.vendor_id.slice(0, 8)}...</p>
                        </div>
                      </td>
                      <td className="p-3 text-right font-bold text-green-600">
                        ₹{w.amount.toFixed(2)}
                      </td>
                      <td className="p-3">
                        {w.bank_snapshot ? (
                          <div className="text-xs">
                            <p>{w.bank_snapshot.account_holder_name}</p>
                            <p className="text-gray-500">{w.bank_snapshot.bank_name}</p>
                            <p className="text-gray-500">{w.bank_snapshot.ifsc_code}</p>
                          </div>
                        ) : (
                          <span className="text-gray-400">N/A</span>
                        )}
                      </td>
                      <td className="p-3">
                        <StatusBadge status={w.status} />
                      </td>
                      <td className="p-3 text-xs text-gray-500">
                        {new Date(w.requested_at).toLocaleDateString()}
                      </td>
                      <td className="p-3">
                        {w.status === 'pending' && (
                          <div className="flex gap-2">
                            <Button
                              size="sm"
                              onClick={() => updateWithdrawalStatus(w.id, 'approved')}
                            >
                              Approve
                            </Button>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => updateWithdrawalStatus(w.id, 'rejected')}
                            >
                              Reject
                            </Button>
                          </div>
                        )}
                        {w.status === 'approved' && (
                          <Button
                            size="sm"
                            onClick={() => updateWithdrawalStatus(w.id, 'paid')}
                          >
                            Mark Paid
                          </Button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-700',
    approved: 'bg-blue-100 text-blue-700',
    processing: 'bg-purple-100 text-purple-700',
    paid: 'bg-green-100 text-green-700',
    rejected: 'bg-red-100 text-red-700',
    failed: 'bg-gray-100 text-gray-700',
  }
  return (
    <span className={`px-2 py-1 rounded text-xs ${colors[status] || colors.pending}`}>
      {status}
    </span>
  )
}

