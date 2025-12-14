"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { 
  Headphones, 
  AlertCircle, 
  Clock, 
  CheckCircle, 
  XCircle,
  MessageSquare,
  Filter,
  Plus
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'

interface SupportTicket {
  id: string
  subject: string
  description: string | null
  category: string
  status: string
  priority: string
  created_at: string
  updated_at: string
  user_id: string | null
  vendor_id: string | null
  profiles?: { full_name: string; email: string } | null
  vendor_profiles?: { business_name: string } | null
}

const CATEGORIES = ['General', 'Booking', 'Payment', 'Technical', 'Vendor', 'Refund', 'Other']
const PRIORITIES = ['low', 'medium', 'high', 'urgent']
const STATUSES = ['open', 'in_progress', 'resolved', 'closed']

export default function SupportPage() {
  const supabase = createClient()
  const [tickets, setTickets] = useState<SupportTicket[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [categoryFilter, setCategoryFilter] = useState<string>('all')
  const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null)

  useEffect(() => {
    loadTickets()
  }, [])

  async function loadTickets() {
    setLoading(true)
    setError(null)
    
    const { data, error } = await supabase
      .from('support_tickets')
      .select(`
        id,
        subject,
        description,
        category,
        status,
        priority,
        created_at,
        updated_at,
        user_id,
        vendor_id,
        profiles(full_name, email),
        vendor_profiles(business_name)
      `)
      .order('created_at', { ascending: false })
      .limit(200)
    
    if (error) {
      // If table doesn't exist, show empty state
      if (error.code === '42P01') {
        setTickets([])
      } else {
        setError(error.message)
      }
    } else {
      // Transform Supabase response: arrays to single objects
      const transformedData = (data || []).map((ticket: any) => ({
        ...ticket,
        profiles: Array.isArray(ticket.profiles) && ticket.profiles.length > 0 
          ? ticket.profiles[0] 
          : null,
        vendor_profiles: Array.isArray(ticket.vendor_profiles) && ticket.vendor_profiles.length > 0 
          ? ticket.vendor_profiles[0] 
          : null,
      })) as SupportTicket[]
      setTickets(transformedData)
    }
    setLoading(false)
  }

  async function updateTicketStatus(ticketId: string, newStatus: string) {
    const { error } = await supabase
      .from('support_tickets')
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq('id', ticketId)
    
    if (!error) {
      setTickets(prev => prev.map(t => 
        t.id === ticketId ? { ...t, status: newStatus } : t
      ))
      if (selectedTicket?.id === ticketId) {
        setSelectedTicket(prev => prev ? { ...prev, status: newStatus } : null)
      }
    }
  }

  const filteredTickets = tickets.filter(ticket => {
    if (statusFilter !== 'all' && ticket.status !== statusFilter) return false
    if (categoryFilter !== 'all' && ticket.category !== categoryFilter) return false
    if (search) {
      const q = search.toLowerCase()
      const subject = ticket.subject?.toLowerCase() || ''
      const userName = ticket.profiles?.full_name?.toLowerCase() || ''
      const email = ticket.profiles?.email?.toLowerCase() || ''
      if (!subject.includes(q) && !userName.includes(q) && !email.includes(q) && !ticket.id.includes(q)) {
        return false
      }
    }
    return true
  })

  const stats = {
    total: tickets.length,
    open: tickets.filter(t => t.status === 'open').length,
    inProgress: tickets.filter(t => t.status === 'in_progress').length,
    resolved: tickets.filter(t => t.status === 'resolved').length,
  }

  const categoryStats = CATEGORIES.map(cat => ({
    category: cat,
    count: tickets.filter(t => t.category === cat).length
  })).filter(c => c.count > 0)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Support Tickets</h1>
          <p className="text-gray-600">Manage customer complaints and support requests</p>
        </div>
        <Button onClick={loadTickets} disabled={loading}>
          {loading ? 'Refreshing...' : 'Refresh'}
        </Button>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-blue-50 rounded-full">
              <Headphones className="h-6 w-6 text-blue-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Tickets</p>
              <p className="text-2xl font-bold text-gray-900">{stats.total}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-red-200 bg-red-50/30">
          <div className="flex items-center">
            <div className="p-3 bg-red-100 rounded-full">
              <AlertCircle className="h-6 w-6 text-red-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Open</p>
              <p className="text-2xl font-bold text-red-600">{stats.open}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-yellow-200 bg-yellow-50/30">
          <div className="flex items-center">
            <div className="p-3 bg-yellow-100 rounded-full">
              <Clock className="h-6 w-6 text-yellow-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">In Progress</p>
              <p className="text-2xl font-bold text-yellow-600">{stats.inProgress}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-green-200 bg-green-50/30">
          <div className="flex items-center">
            <div className="p-3 bg-green-100 rounded-full">
              <CheckCircle className="h-6 w-6 text-green-500" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Resolved</p>
              <p className="text-2xl font-bold text-green-600">{stats.resolved}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Category Breakdown */}
      {categoryStats.length > 0 && (
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <h3 className="text-lg font-semibold mb-4">Tickets by Category</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
            {categoryStats.map(({ category, count }) => (
              <div 
                key={category} 
                className="p-3 bg-gray-50 rounded-lg text-center cursor-pointer hover:bg-gray-100"
                onClick={() => setCategoryFilter(category)}
              >
                <p className="text-lg font-bold text-gray-900">{count}</p>
                <p className="text-xs text-gray-600">{category}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg border border-gray-200">
        <div className="flex flex-wrap gap-4 items-center">
          <div className="flex-1 min-w-[200px]">
            <Input
              placeholder="Search by subject, user, or ticket ID..."
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
            {STATUSES.map(s => (
              <option key={s} value={s}>{s.replace('_', ' ')}</option>
            ))}
          </select>
          <select
            className="h-10 rounded-md border border-input bg-background px-3 text-sm"
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
          >
            <option value="all">All categories</option>
            {CATEGORIES.map(c => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Tickets Table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-500">Loading tickets...</div>
        ) : error ? (
          <div className="p-8 text-center text-red-600">{error}</div>
        ) : filteredTickets.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <Headphones className="h-12 w-12 mx-auto text-gray-300 mb-4" />
            <p>No support tickets found</p>
            <p className="text-sm text-gray-400 mt-1">Tickets will appear here when customers submit them</p>
          </div>
        ) : (
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-left">
              <tr>
                <th className="p-3">Subject</th>
                <th className="p-3">User</th>
                <th className="p-3">Category</th>
                <th className="p-3">Priority</th>
                <th className="p-3">Status</th>
                <th className="p-3">Created</th>
                <th className="p-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredTickets.map((ticket) => (
                <tr key={ticket.id} className="hover:bg-gray-50">
                  <td className="p-3">
                    <div>
                      <p className="font-medium text-gray-900 line-clamp-1">{ticket.subject}</p>
                      <p className="text-xs text-gray-500 font-mono">{ticket.id.slice(0, 8)}...</p>
                    </div>
                  </td>
                  <td className="p-3">
                    <p className="text-gray-900">{ticket.profiles?.full_name || 'Unknown'}</p>
                    <p className="text-xs text-gray-500">{ticket.profiles?.email || ''}</p>
                  </td>
                  <td className="p-3">
                    <span className="px-2 py-1 bg-gray-100 text-gray-700 rounded text-xs">
                      {ticket.category}
                    </span>
                  </td>
                  <td className="p-3">
                    <PriorityBadge priority={ticket.priority} />
                  </td>
                  <td className="p-3">
                    <StatusBadge status={ticket.status} />
                  </td>
                  <td className="p-3 text-gray-500 text-xs">
                    {new Date(ticket.created_at).toLocaleDateString()}
                  </td>
                  <td className="p-3">
                    <select
                      className="text-xs border rounded px-2 py-1"
                      value={ticket.status}
                      onChange={(e) => updateTicketStatus(ticket.id, e.target.value)}
                    >
                      {STATUSES.map(s => (
                        <option key={s} value={s}>{s.replace('_', ' ')}</option>
                      ))}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    open: 'bg-red-100 text-red-700',
    in_progress: 'bg-yellow-100 text-yellow-700',
    resolved: 'bg-green-100 text-green-700',
    closed: 'bg-gray-100 text-gray-700',
  }
  return (
    <span className={`px-2 py-1 rounded text-xs ${colors[status] || colors.open}`}>
      {status.replace('_', ' ')}
    </span>
  )
}

function PriorityBadge({ priority }: { priority: string }) {
  const colors: Record<string, string> = {
    low: 'bg-gray-100 text-gray-600',
    medium: 'bg-blue-100 text-blue-700',
    high: 'bg-orange-100 text-orange-700',
    urgent: 'bg-red-100 text-red-700',
  }
  return (
    <span className={`px-2 py-1 rounded text-xs ${colors[priority] || colors.medium}`}>
      {priority}
    </span>
  )
}

