"use client"
import { useEffect, useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { useAuth } from '@/contexts/AuthContext'
import { Eye, CheckCircle2, XCircle, Clock, Search } from 'lucide-react'

type VendorRow = {
  id: string
  business_name: string
  vendor_name?: string | null
  address?: string | null
  category?: string | null
  phone_number?: string | null
  approval_status: 'pending' | 'approved' | 'rejected'
  approval_notes?: string | null
  profile_picture_url?: string | null
  created_at: string
  updated_at: string
}

type VendorDocumentRow = {
  id: string
  vendor_id: string
  document_type: string
  file_name: string
  file_url: string
  uploaded_at: string
}

export default function VendorsPage() {
  const supabase = createClient()
  const { user } = useAuth()
  const [vendors, setVendors] = useState<VendorRow[]>([])
  const [documents, setDocuments] = useState<Record<string, VendorDocumentRow[]>>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedVendorId, setSelectedVendorId] = useState<string | null>(null)
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected'>('pending')
  const [searchQuery, setSearchQuery] = useState('')

  useEffect(() => {
    load()
  }, [])

  async function load() {
    setLoading(true)
    setError(null)

    try {
      // Load vendors with approval fields - use pagination
      const { data, error } = await supabase
        .from('vendor_profiles')
        .select('id, business_name, vendor_name, address, category, phone_number, approval_status, approval_notes, profile_picture_url, created_at, updated_at')
        .order('created_at', { ascending: false })
        .limit(100) // Reduced from 500 for better performance

      if (error) throw error
      const rows = (data || []) as VendorRow[]
      setVendors(rows)

      // Don't load documents upfront - load them lazily when vendor is selected
      setDocuments({})
    } catch (err: any) {
      console.error('Error loading vendors:', err)
      setError(err.message || 'Failed to load vendors')
    } finally {
      setLoading(false)
    }
  }

  // Load documents for a specific vendor when needed
  async function loadVendorDocuments(vendorId: string) {
    if (documents[vendorId]) return // Already loaded

    try {
      const { data: docs, error: docError } = await supabase
        .from('vendor_documents')
        .select('id, vendor_id, document_type, file_name, file_url, uploaded_at')
        .eq('vendor_id', vendorId)
        .order('uploaded_at', { ascending: false })

      if (docError) throw docError

      setDocuments(prev => ({
        ...prev,
        [vendorId]: (docs || []) as VendorDocumentRow[]
      }))
    } catch (err: any) {
      console.error('Error loading documents:', err)
    }
  }

  async function updateApproval(vendorId: string, status: 'approved' | 'rejected', notes?: string) {
    if (updatingId) return
    setUpdatingId(vendorId)
    try {
      const payload: any = {
        approval_status: status,
        approval_notes: notes || null,
        approved_at: status === 'approved' ? new Date().toISOString() : null,
      }
      if (user?.id) {
        payload.approved_by = user.id
      }
      const { error } = await supabase
        .from('vendor_profiles')
        .update(payload)
        .eq('id', vendorId)

      if (error) throw error
      await load()
    } catch (err: any) {
      console.error('Failed to update vendor approval:', err)
      alert(err.message || 'Failed to update vendor approval')
    } finally {
      setUpdatingId(null)
    }
  }

  // Filter vendors based on search query
  const filteredVendors = useMemo(() => {
    if (!searchQuery.trim()) return vendors
    
    const query = searchQuery.toLowerCase().trim()
    return vendors.filter(v => {
      const businessName = (v.business_name || '').toLowerCase()
      const vendorName = (v.vendor_name || '').toLowerCase()
      const category = (v.category || '').toLowerCase()
      const phone = (v.phone_number || '').toLowerCase()
      const address = (v.address || '').toLowerCase()
      const vendorId = (v.id || '').toLowerCase()
      
      return businessName.includes(query) ||
             vendorName.includes(query) ||
             category.includes(query) ||
             phone.includes(query) ||
             address.includes(query) ||
             vendorId.includes(query)
    })
  }, [vendors, searchQuery])

  const pending = filteredVendors.filter(v => v.approval_status === 'pending')
  const approved = filteredVendors.filter(v => v.approval_status === 'approved')
  const rejected = filteredVendors.filter(v => v.approval_status === 'rejected')

  function renderStatusBadge(status: VendorRow['approval_status']) {
    const base = 'inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium'
    if (status === 'approved') {
      return (
        <span className={`${base} bg-green-100 text-green-700`}>
          <CheckCircle2 className="h-3 w-3" /> Approved
        </span>
      )
    }
    if (status === 'rejected') {
      return (
        <span className={`${base} bg-red-100 text-red-700`}>
          <XCircle className="h-3 w-3" /> Rejected
        </span>
      )
    }
    return (
      <span className={`${base} bg-yellow-100 text-yellow-700`}>
        <Clock className="h-3 w-3" /> Pending
      </span>
    )
  }

  function renderVendorTable(list: VendorRow[]) {
    return (
      <div className="bg-white rounded-xl border overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50 text-left">
            <tr>
              <th className="p-3">Business</th>
              <th className="p-3">Vendor</th>
              <th className="p-3">Category</th>
              <th className="p-3">Phone</th>
              <th className="p-3">Address</th>
              <th className="p-3">Status</th>
              <th className="p-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td className="p-3" colSpan={6}>Loading...</td></tr>
            ) : list.length === 0 ? (
              <tr><td className="p-3" colSpan={6}>No vendors in this category</td></tr>
            ) : list.map(v => (
              <tr key={v.id} className="border-t hover:bg-gray-50">
                <td className="p-3">
                  <div className="flex items-center gap-3">
                    {v.profile_picture_url ? (
                      <img
                        src={v.profile_picture_url}
                        alt={v.business_name}
                        className="w-10 h-10 rounded-full object-cover"
                        onError={(e) => {
                          // Fallback to default icon if image fails to load
                          (e.target as HTMLImageElement).style.display = 'none';
                        }}
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center">
                        <span className="text-gray-500 text-xs font-medium">
                          {v.business_name.substring(0, 2).toUpperCase()}
                        </span>
                      </div>
                    )}
                    <span className="font-medium">{v.business_name}</span>
                  </div>
                </td>
                <td className="p-3">{v.vendor_name ?? '-'}</td>
                <td className="p-3">{v.category ?? '-'}</td>
                <td className="p-3">{v.phone_number ?? '-'}</td>
                <td className="p-3">{v.address ?? '-'}</td>
                <td className="p-3">
                  {renderStatusBadge(v.approval_status)}
                </td>
                <td className="p-3 text-right space-x-2">
                  {/* View Docs button available for all vendors (pending, approved, rejected) */}
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setSelectedVendorId(v.id)}
                  >
                    <Eye className="h-4 w-4 mr-1" />
                    View Docs
                  </Button>
                  {v.approval_status !== 'approved' && (
                    <Button
                      size="sm"
                      onClick={() => updateApproval(v.id, 'approved')}
                      loading={updatingId === v.id}
                    >
                      Approve
                    </Button>
                  )}
                  {v.approval_status !== 'rejected' && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        const reason = window.prompt('Reason for rejection (optional):') || undefined
                        updateApproval(v.id, 'rejected', reason)
                      }}
                      disabled={updatingId === v.id}
                    >
                      Reject
                    </Button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    )
  }

  // Load documents when vendor is selected
  useEffect(() => {
    if (selectedVendorId) {
      loadVendorDocuments(selectedVendorId)
    }
  }, [selectedVendorId])

  const selectedDocs = selectedVendorId ? documents[selectedVendorId] || [] : []
  const selectedVendor = vendors.find(v => v.id === selectedVendorId) || null

  return (
    <main className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">Vendors</h1>
          <p className="text-sm text-gray-600">Review vendor documents and approve or reject accounts. You can view documents for all vendors, including approved ones.</p>
        </div>
        <Button variant="outline" onClick={load} disabled={loading}>
          Refresh
        </Button>
      </div>

      {error && (
        <div className="rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Search Bar */}
      <div>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
          <input
            type="text"
            placeholder="Search by business name, vendor name, category, phone, address, or vendor ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
        {searchQuery && (
          <p className="mt-2 text-sm text-gray-600">
            Found {filteredVendors.length} vendor{filteredVendors.length !== 1 ? 's' : ''} matching "{searchQuery}"
          </p>
        )}
      </div>

      {/* Tab Bar */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8" aria-label="Tabs">
          <button
            onClick={() => setActiveTab('pending')}
            className={`
              whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
              ${activeTab === 'pending'
                ? 'border-yellow-500 text-yellow-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }
            `}
          >
            <div className="flex items-center gap-2">
              <Clock className="h-4 w-4" />
              Pending Approval
              <span className={`
                ml-2 py-0.5 px-2 rounded-full text-xs font-medium
                ${activeTab === 'pending'
                  ? 'bg-yellow-100 text-yellow-700'
                  : 'bg-gray-100 text-gray-600'
                }
              `}>
                {pending.length}
              </span>
            </div>
          </button>
          <button
            onClick={() => setActiveTab('approved')}
            className={`
              whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
              ${activeTab === 'approved'
                ? 'border-green-500 text-green-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }
            `}
          >
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4" />
              Approved Vendors
              <span className={`
                ml-2 py-0.5 px-2 rounded-full text-xs font-medium
                ${activeTab === 'approved'
                  ? 'bg-green-100 text-green-700'
                  : 'bg-gray-100 text-gray-600'
                }
              `}>
                {approved.length}
              </span>
            </div>
          </button>
          {rejected.length > 0 && (
            <button
              onClick={() => setActiveTab('rejected')}
              className={`
                whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
                ${activeTab === 'rejected'
                  ? 'border-red-500 text-red-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }
              `}
            >
              <div className="flex items-center gap-2">
                <XCircle className="h-4 w-4" />
                Rejected Vendors
                <span className={`
                  ml-2 py-0.5 px-2 rounded-full text-xs font-medium
                  ${activeTab === 'rejected'
                    ? 'bg-red-100 text-red-700'
                    : 'bg-gray-100 text-gray-600'
                  }
                `}>
                  {rejected.length}
                </span>
              </div>
            </button>
          )}
        </nav>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-4">
          {activeTab === 'pending' && renderVendorTable(pending)}
          {activeTab === 'approved' && renderVendorTable(approved)}
          {activeTab === 'rejected' && renderVendorTable(rejected)}
        </div>

        {/* Documents viewer */}
        <div className="bg-white rounded-xl border p-4 space-y-3">
          <h2 className="text-sm font-semibold text-gray-700 flex items-center gap-2 mb-2">
            <Eye className="h-4 w-4 text-blue-600" />
            Vendor Documents
          </h2>
          {selectedVendor ? (
            <>
              <div className="text-sm text-gray-700 mb-2">
                <div className="flex items-center gap-3 mb-2">
                  {selectedVendor.profile_picture_url ? (
                    <img
                      src={selectedVendor.profile_picture_url}
                      alt={selectedVendor.business_name}
                      className="w-16 h-16 rounded-full object-cover border-2 border-gray-200"
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = 'none';
                      }}
                    />
                  ) : (
                    <div className="w-16 h-16 rounded-full bg-gray-200 flex items-center justify-center border-2 border-gray-200">
                      <span className="text-gray-500 text-lg font-medium">
                        {selectedVendor.business_name.substring(0, 2).toUpperCase()}
                      </span>
                    </div>
                  )}
                  <div className="flex-1">
                    <div className="font-medium text-base">{selectedVendor.business_name}</div>
                    <div className="text-xs text-gray-500">
                      {selectedVendor.category ?? '-'} • {selectedVendor.phone_number ?? '-'}
                    </div>
                  </div>
                </div>
                <div className="mt-1">
                  {renderStatusBadge(selectedVendor.approval_status)}
                </div>
                {selectedVendor.approval_notes && (
                  <div className="mt-1 text-xs text-gray-500">
                    Notes: {selectedVendor.approval_notes}
                  </div>
                )}
              </div>
              {selectedDocs.length === 0 ? (
                <p className="text-sm text-gray-500">No documents uploaded for this vendor.</p>
              ) : (
                <div className="space-y-2 max-h-[480px] overflow-y-auto">
                  {selectedDocs.map(doc => (
                    <div
                      key={doc.id}
                      className="flex items-center justify-between border rounded-md px-3 py-2 hover:bg-gray-50"
                    >
                      <div>
                        <div className="text-sm font-medium text-gray-800">{doc.document_type}</div>
                        <div className="text-xs text-gray-500">
                          {doc.file_name} • {new Date(doc.uploaded_at).toLocaleString()}
                        </div>
                      </div>
                      <a
                        href={doc.file_url}
                        target="_blank"
                        rel="noreferrer"
                        className="text-sm text-blue-600 hover:underline"
                      >
                        Open
                      </a>
                    </div>
                  ))}
                </div>
              )}
            </>
          ) : (
            <p className="text-sm text-gray-500">
              Select a vendor from the table to view their documents.
            </p>
          )}
        </div>
      </div>
    </main>
  )
}


