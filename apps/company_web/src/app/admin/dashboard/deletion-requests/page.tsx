"use client"
import { useEffect, useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { CheckCircle2, XCircle, Clock, Trash2, UserX } from 'lucide-react'

type DeletionRequest = {
  id: string
  vendor_id: string
  user_id: string
  reason: string
  suggestions?: string | null
  status: 'pending' | 'completed' | 'cancelled'
  created_at: string
  vendor_profiles: {
    business_name: string
    email?: string | null
    phone_number?: string | null
  }
}

export default function DeletionRequestsPage() {
  const supabase = createClient()
  const [requests, setRequests] = useState<DeletionRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [processingId, setProcessingId] = useState<string | null>(null)

  useEffect(() => {
    load()
  }, [])

  async function load() {
    setLoading(true)
    setError(null)

    try {
      const { data, error } = await supabase
        .from('account_deletion_requests')
        .select(`
          *,
          vendor_profiles (
            business_name,
            email,
            phone_number
          )
        `)
        .order('created_at', { ascending: false })

      if (error) throw error
      setRequests((data || []) as DeletionRequest[])
    } catch (err: any) {
      console.error('Error loading requests:', err)
      setError(err.message || 'Failed to load deletion requests')
    } finally {
      setLoading(false)
    }
  }

  async function handleDeleteUser(requestId: string, vendorId: string, userId: string) {
    if (!confirm('Are you absolutely sure? This will delete the vendor profile, all their business data, and potentially their login account permanently.')) return

    setProcessingId(requestId)
    try {
      // Call the permanent deletion function
      const { error: deletionError } = await supabase.rpc('permanently_delete_vendor', {
        p_vendor_id: vendorId,
        p_user_id: userId
      })

      if (deletionError) throw deletionError

      alert('Vendor data and account processed successfully.')
      load()
    } catch (err: any) {
      console.error('Failed to process deletion:', err)
      alert('Error: ' + err.message)
    } finally {
      setProcessingId(null)
    }
  }

  async function handleCancelRequest(requestId: string) {
    if (!confirm('Cancel this deletion request?')) return

    setProcessingId(requestId)
    try {
      const { error } = await supabase
        .from('account_deletion_requests')
        .update({ status: 'cancelled' })
        .eq('id', requestId)

      if (error) throw error
      load()
    } catch (err: any) {
      alert('Error: ' + err.message)
    } finally {
      setProcessingId(null)
    }
  }

  return (
    <main className="p-6 space-y-6">
      <div>
        <h1 className="text-xl font-semibold flex items-center gap-2">
          <UserX className="h-6 w-6 text-red-600" />
          Account Deletion Requests
        </h1>
        <p className="text-sm text-gray-600">Review reasons and suggestions from vendors requesting account closure.</p>
      </div>

      {error && (
        <div className="rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="bg-white rounded-xl border overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50 text-left">
            <tr>
              <th className="p-4">Vendor</th>
              <th className="p-4">Date Requested</th>
              <th className="p-4">Reason</th>
              <th className="p-4">Suggestions</th>
              <th className="p-4">Status</th>
              <th className="p-4 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td className="p-4 text-center" colSpan={6}>Loading requests...</td></tr>
            ) : requests.length === 0 ? (
              <tr><td className="p-4 text-center" colSpan={6}>No deletion requests found</td></tr>
            ) : requests.map(req => (
              <tr key={req.id} className="hover:bg-gray-50 transition-colors">
                <td className="p-4">
                  <div className="font-medium text-gray-900">{req.vendor_profiles?.business_name || 'Unknown Vendor'}</div>
                  <div className="text-xs text-gray-500">{req.vendor_profiles?.email || req.user_id}</div>
                </td>
                <td className="p-4 whitespace-nowrap text-gray-600">
                  {new Date(req.created_at).toLocaleDateString()}
                  <div className="text-xs text-gray-400">{new Date(req.created_at).toLocaleTimeString()}</div>
                </td>
                <td className="p-4">
                  <span className="inline-block max-w-[200px] truncate" title={req.reason}>
                    {req.reason}
                  </span>
                </td>
                <td className="p-4">
                  <span className="text-gray-500 italic">
                    {req.suggestions || 'No feedback provided'}
                  </span>
                </td>
                <td className="p-4">
                  <StatusBadge status={req.status} />
                </td>
                <td className="p-4 text-right space-x-2">
                  {req.status === 'pending' && (
                    <>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => handleDeleteUser(req.id, req.vendor_id, req.user_id)}
                        loading={processingId === req.id}
                      >
                        <Trash2 className="h-4 w-4 mr-1" />
                        Confirm & Delete
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleCancelRequest(req.id)}
                        disabled={processingId === req.id}
                      >
                        Ignore
                      </Button>
                    </>
                  )}
                  {req.status !== 'pending' && (
                    <span className="text-xs text-gray-400 italic">Processed</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </main>
  )
}

function StatusBadge({ status }: { status: DeletionRequest['status'] }) {
  const configs = {
    pending: { color: 'bg-yellow-100 text-yellow-700', icon: Clock, label: 'Pending' },
    completed: { color: 'bg-green-100 text-green-700', icon: CheckCircle2, label: 'Deleted' },
    cancelled: { color: 'bg-gray-100 text-gray-700', icon: XCircle, label: 'Ignored' },
  }
  const config = configs[status]
  const Icon = config.icon
  return (
    <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium ${config.color}`}>
      <Icon className="h-3 w-3" />
      {config.label}
    </span>
  )
}
