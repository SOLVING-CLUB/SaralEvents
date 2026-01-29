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
  Plus,
  Edit,
  Trash2,
  Eye,
  HelpCircle,
  Search,
  X,
  Users,
  Store
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'

interface SupportTicket {
  id: string
  subject: string
  message: string
  category: string
  status: string
  priority: string
  created_at: string
  updated_at: string
  user_id: string | null
  vendor_id: string | null
  order_id: string | null
  contact_number: string | null
  admin_notes?: string | null
  profiles?: { first_name?: string; last_name?: string; email: string; phone_number?: string } | null
  vendor_profiles?: { business_name: string } | null
}

interface FAQ {
  id: string
  question: string
  answer: string
  category: string
  app_type: 'user_app' | 'vendor_app'
  display_order: number
  is_active: boolean
  view_count: number
  helpful_count: number
  not_helpful_count: number
  created_at: string
  updated_at: string
}

const TICKET_CATEGORIES = ['General', 'Booking Issue', 'Payment/Refund', 'Cancellation', 'Technical Issue', 'General Inquiry', 'Complaint', 'Other']
const FAQ_CATEGORIES = ['General', 'Booking', 'Payment', 'Cancellation', 'Refund', 'Technical', 'Account', 'Vendor', 'Other']
const PRIORITIES = ['low', 'medium', 'high', 'urgent']
const STATUSES = ['open', 'in_progress', 'resolved', 'closed']

export default function SupportPage() {
  const supabase = createClient()
  const [activeTab, setActiveTab] = useState<'tickets' | 'faqs'>('tickets')
  
  // Tickets state
  const [tickets, setTickets] = useState<SupportTicket[]>([])
  const [ticketsLoading, setTicketsLoading] = useState(true)
  const [ticketsError, setTicketsError] = useState<string | null>(null)
  const [ticketSearch, setTicketSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [categoryFilter, setCategoryFilter] = useState<string>('all')
  const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null)
  const [showTicketModal, setShowTicketModal] = useState(false)
  const [statusUpdateMessage, setStatusUpdateMessage] = useState('')
  const [pendingStatus, setPendingStatus] = useState<string | null>(null)
  
  // FAQs state
  const [faqs, setFaqs] = useState<FAQ[]>([])
  const [faqsLoading, setFaqsLoading] = useState(true)
  const [faqsError, setFaqsError] = useState<string | null>(null)
  const [faqSearch, setFaqSearch] = useState('')
  const [faqCategoryFilter, setFaqCategoryFilter] = useState<string>('all')
  const [faqAppTypeFilter, setFaqAppTypeFilter] = useState<'user_app' | 'vendor_app'>('user_app')
  const [showFaqModal, setShowFaqModal] = useState(false)
  const [editingFaq, setEditingFaq] = useState<FAQ | null>(null)
  const [faqForm, setFaqForm] = useState({
    question: '',
    answer: '',
    category: 'General',
    app_type: 'user_app' as 'user_app' | 'vendor_app',
    display_order: 0,
    is_active: true
  })

  useEffect(() => {
    if (activeTab === 'tickets') {
      loadTickets()
    } else {
      loadFAQs()
    }
  }, [activeTab])

  // Load Tickets
  async function loadTickets() {
    setTicketsLoading(true)
    setTicketsError(null)
    
    try {
      const { data, error } = await supabase
        .from('support_tickets')
        .select(`
          id,
          subject,
          message,
          category,
          status,
          priority,
          created_at,
          updated_at,
          user_id,
          vendor_id,
          order_id,
          contact_number,
          admin_notes
        `)
        .order('created_at', { ascending: false })
        .limit(200)
      
      if (error) {
        if (error.code === '42P01') {
          setTickets([])
        } else {
          setTicketsError(error.message)
        }
      } else {
        // Fetch user profiles separately
        const ticketsWithProfiles = await Promise.all((data || []).map(async (ticket: any) => {
          let profiles = null
          let vendor_profiles = null
          
          if (ticket.user_id) {
            const { data: userData } = await supabase
              .from('user_profiles')
              .select('first_name, last_name, email, phone_number')
              .eq('user_id', ticket.user_id)
              .maybeSingle()
            profiles = userData
          }
          
          if (ticket.vendor_id) {
            const { data: vendorData } = await supabase
              .from('vendor_profiles')
              .select('business_name')
              .eq('id', ticket.vendor_id)
              .maybeSingle()
            vendor_profiles = vendorData
          }
          
          return {
            ...ticket,
            profiles,
            vendor_profiles
          }
        }))
        
        setTickets(ticketsWithProfiles as SupportTicket[])
      }
    } catch (err: any) {
      setTicketsError(err.message)
    }
    setTicketsLoading(false)
  }

  // Load FAQs
  async function loadFAQs() {
    setFaqsLoading(true)
    setFaqsError(null)
    
    try {
      const { data, error } = await supabase
        .from('faqs')
        .select('*')
        .order('display_order', { ascending: true })
        .order('created_at', { ascending: false })
      
      if (error) {
        if (error.code === '42P01') {
          setFaqs([])
        } else {
          setFaqsError(error.message)
        }
      } else {
        setFaqs(data || [])
      }
    } catch (err: any) {
      setFaqsError(err.message)
    }
    setFaqsLoading(false)
  }

  // Update Ticket Status (and send notification message - message is required)
  async function updateTicketStatus(ticket: SupportTicket, newStatus: string, message: string) {
    const trimmedMessage = message?.trim()
    if (!trimmedMessage) {
      alert('Please enter a message to send to the user/vendor before updating the status.')
      return
    }

    const { error } = await supabase
      .from('support_tickets')
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq('id', ticket.id)
    
    if (error) {
      console.error('Error updating ticket status:', error)
      alert(`Error updating ticket status: ${error.message}`)
      return
    }

    // Update local state
    setTickets(prev => prev.map(t => 
      t.id === ticket.id ? { ...t, status: newStatus } : t
    ))
    if (selectedTicket?.id === ticket.id) {
      setSelectedTicket(prev => prev ? { ...prev, status: newStatus } : null)
      setStatusUpdateMessage('')
      setPendingStatus(null)
    }

    try {
      // Determine target user and app type (user or vendor)
      let targetUserId: string | null = null
      let appTypes: string[] = []

      if (ticket.user_id) {
        // Ticket created by user app customer
        targetUserId = ticket.user_id
        appTypes = ['user_app']
      } else if (ticket.vendor_id) {
        // Ticket linked to a vendor – fetch vendor's auth user_id
        const { data: vendorProfile, error: vendorError } = await supabase
          .from('vendor_profiles')
          .select('user_id')
          .eq('id', ticket.vendor_id)
          .maybeSingle()

        if (vendorError) {
          console.error('Error fetching vendor profile for notification:', vendorError)
        }

        if (vendorProfile?.user_id) {
          targetUserId = vendorProfile.user_id
          appTypes = ['vendor_app']
        }
      }

      if (!targetUserId || appTypes.length === 0) {
        // Nothing to notify (e.g. missing user/vendor mapping)
        return
      }

      const title = `Support ticket ${newStatus.replace('_', ' ')}`
      const notificationData: any = {
        type: 'support_ticket_update',
        ticket_id: ticket.id,
        status: newStatus,
      }

      const { error: fnError } = await supabase.functions.invoke('send-push-notification', {
        body: {
          userId: targetUserId,
          title,
          body: trimmedMessage,
          data: notificationData,
          appTypes,
        },
      })

      if (fnError) {
        console.error('Error sending support ticket notification:', fnError)
      }
    } catch (err) {
      console.error('Unexpected error sending support ticket notification:', err)
    }
  }

  // Update Ticket Admin Notes
  async function updateTicketNotes(ticketId: string, notes: string) {
    const { error } = await supabase
      .from('support_tickets')
      .update({ admin_notes: notes, updated_at: new Date().toISOString() })
      .eq('id', ticketId)
    
    if (!error) {
      setTickets(prev => prev.map(t => 
        t.id === ticketId ? { ...t, admin_notes: notes } : t
      ))
      if (selectedTicket?.id === ticketId) {
        setSelectedTicket(prev => prev ? { ...prev, admin_notes: notes } : null)
      }
    }
  }

  // Create/Update FAQ
  async function saveFAQ() {
    if (!faqForm.question.trim() || !faqForm.answer.trim()) {
      alert('Please fill in both question and answer')
      return
    }

    try {
      if (editingFaq) {
        // Update existing FAQ
        const { error } = await supabase
          .from('faqs')
          .update({
            question: faqForm.question,
            answer: faqForm.answer,
            category: faqForm.category,
            app_type: faqForm.app_type,
            display_order: faqForm.display_order,
            is_active: faqForm.is_active,
            updated_at: new Date().toISOString()
          })
          .eq('id', editingFaq.id)
        
        if (error) throw error
      } else {
        // Create new FAQ
        const { data: { user } } = await supabase.auth.getUser()
        const { error } = await supabase
          .from('faqs')
          .insert({
            question: faqForm.question,
            answer: faqForm.answer,
            category: faqForm.category,
            app_type: faqForm.app_type,
            display_order: faqForm.display_order,
            is_active: faqForm.is_active,
            created_by: user?.id
          })
        
        if (error) throw error
      }
      
      setShowFaqModal(false)
      setEditingFaq(null)
      setFaqForm({
        question: '',
        answer: '',
        category: 'General',
        app_type: faqAppTypeFilter,
        display_order: 0,
        is_active: true
      })
      loadFAQs()
    } catch (err: any) {
      alert(`Error saving FAQ: ${err.message}`)
    }
  }

  // Delete FAQ
  async function deleteFAQ(faqId: string) {
    if (!confirm('Are you sure you want to delete this FAQ?')) return
    
    try {
      const { error } = await supabase
        .from('faqs')
        .delete()
        .eq('id', faqId)
      
      if (error) throw error
      loadFAQs()
    } catch (err: any) {
      alert(`Error deleting FAQ: ${err.message}`)
    }
  }

  // Edit FAQ
  function editFAQ(faq: FAQ) {
    setEditingFaq(faq)
    setFaqForm({
      question: faq.question,
      answer: faq.answer,
      category: faq.category,
      app_type: faq.app_type,
      display_order: faq.display_order,
      is_active: faq.is_active
    })
    setShowFaqModal(true)
  }

  // Filter Tickets
  const filteredTickets = tickets.filter(ticket => {
    if (statusFilter !== 'all' && ticket.status !== statusFilter) return false
    if (categoryFilter !== 'all' && ticket.category !== categoryFilter) return false
    if (ticketSearch) {
      const q = ticketSearch.toLowerCase()
      const subject = ticket.subject?.toLowerCase() || ''
      const userName = ticket.profiles?.first_name?.toLowerCase() || ''
      const lastName = ticket.profiles?.last_name?.toLowerCase() || ''
      const email = ticket.profiles?.email?.toLowerCase() || ''
      const orderId = ticket.order_id?.toLowerCase() || ''
      if (!subject.includes(q) && !userName.includes(q) && !lastName.includes(q) && !email.includes(q) && !ticket.id.includes(q) && !orderId.includes(q)) {
        return false
      }
    }
    return true
  })

  // Filter FAQs
  const filteredFAQs = faqs.filter(faq => {
    // Filter by app type
    if (faq.app_type !== faqAppTypeFilter) return false
    // Filter by category
    if (faqCategoryFilter !== 'all' && faq.category !== faqCategoryFilter) return false
    // Filter by search
    if (faqSearch) {
      const q = faqSearch.toLowerCase()
      if (!faq.question.toLowerCase().includes(q) && !faq.answer.toLowerCase().includes(q)) {
        return false
      }
    }
    return true
  })

  const ticketStats = {
    total: tickets.length,
    open: tickets.filter(t => t.status === 'open').length,
    inProgress: tickets.filter(t => t.status === 'in_progress').length,
    resolved: tickets.filter(t => t.status === 'resolved').length,
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Support Management</h1>
          <p className="text-gray-600">Manage support tickets and FAQs</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('tickets')}
            className={`py-3 lg:py-4 px-1 border-b-2 font-medium text-xs lg:text-sm whitespace-nowrap ${
              activeTab === 'tickets'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            <div className="flex items-center gap-1 lg:gap-2">
              <Headphones className="h-4 w-4 lg:h-5 lg:w-5" />
              <span className="hidden sm:inline">Support Tickets</span>
              <span className="sm:hidden">Tickets</span>
              <span className="ml-1">({ticketStats.total})</span>
            </div>
          </button>
          <button
            onClick={() => setActiveTab('faqs')}
            className={`py-3 lg:py-4 px-1 border-b-2 font-medium text-xs lg:text-sm whitespace-nowrap ${
              activeTab === 'faqs'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            <div className="flex items-center gap-1 lg:gap-2">
              <HelpCircle className="h-4 w-4 lg:h-5 lg:w-5" />
              <span>FAQs</span>
              <span className="ml-1">({faqs.length})</span>
            </div>
          </button>
        </nav>
      </div>

      {/* Tickets Tab */}
      {activeTab === 'tickets' && (
        <div className="space-y-6">
          {/* Stats Overview */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-4">
            <div className="bg-white p-6 rounded-lg border border-gray-200">
              <div className="flex items-center">
                <div className="p-3 bg-blue-50 rounded-full">
                  <Headphones className="h-6 w-6 text-blue-500" />
                </div>
                <div className="ml-4">
                  <p className="text-sm text-gray-600">Total Tickets</p>
                  <p className="text-2xl font-bold text-gray-900">{ticketStats.total}</p>
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
                  <p className="text-2xl font-bold text-red-600">{ticketStats.open}</p>
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
                  <p className="text-2xl font-bold text-yellow-600">{ticketStats.inProgress}</p>
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
                  <p className="text-2xl font-bold text-green-600">{ticketStats.resolved}</p>
                </div>
              </div>
            </div>
          </div>

          {/* Filters */}
          <div className="bg-white p-4 rounded-lg border border-gray-200">
            <div className="flex flex-wrap gap-4 items-center">
              <div className="flex-1 min-w-[200px]">
                <Input
                  placeholder="Search by subject, user, or ticket ID..."
                  value={ticketSearch}
                  onChange={(e) => setTicketSearch(e.target.value)}
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
                {TICKET_CATEGORIES.map(c => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
              <Button onClick={loadTickets} disabled={ticketsLoading}>
                {ticketsLoading ? 'Refreshing...' : 'Refresh'}
              </Button>
            </div>
          </div>

          {/* Tickets Table */}
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            {ticketsLoading ? (
              <div className="p-8 text-center text-gray-500">Loading tickets...</div>
            ) : ticketsError ? (
              <div className="p-8 text-center text-red-600">{ticketsError}</div>
            ) : filteredTickets.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <Headphones className="h-12 w-12 mx-auto text-gray-300 mb-4" />
                <p>No support tickets found</p>
                <p className="text-sm text-gray-400 mt-1">Tickets will appear here when customers submit them</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full text-sm">
                  <thead className="bg-gray-50 text-left">
                    <tr>
                      <th className="p-3">Subject</th>
                      <th className="p-3 hidden md:table-cell">User</th>
                      <th className="p-3 hidden lg:table-cell">Order ID</th>
                      <th className="p-3 hidden lg:table-cell">Category</th>
                      <th className="p-3 hidden lg:table-cell">Priority</th>
                      <th className="p-3">Status</th>
                      <th className="p-3 hidden md:table-cell">Created</th>
                      <th className="p-3">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {filteredTickets.map((ticket) => {
                      const fullName = ticket.profiles 
                        ? `${ticket.profiles.first_name || ''} ${ticket.profiles.last_name || ''}`.trim() || 'Unknown'
                        : 'Unknown'
                      
                      return (
                        <tr key={ticket.id} className="hover:bg-gray-50">
                          <td className="p-3">
                            <div>
                              <p className="font-medium text-gray-900 line-clamp-1">{ticket.subject}</p>
                              <p className="text-xs text-gray-500 font-mono md:hidden">{ticket.id.slice(0, 8)}...</p>
                              <div className="md:hidden mt-1 space-y-1">
                                <p className="text-xs text-gray-600">{fullName}</p>
                                {ticket.order_id && (
                                  <a
                                    href={`/dashboard/orders/${ticket.order_id}`}
                                    className="text-xs text-blue-600 hover:underline font-mono"
                                  >
                                    Order: {ticket.order_id.substring(0, 8)}...
                                  </a>
                                )}
                                <span className="inline-block px-2 py-0.5 bg-gray-100 text-gray-700 rounded text-xs">
                                  {ticket.category}
                                </span>
                              </div>
                            </div>
                          </td>
                          <td className="p-3 hidden md:table-cell">
                            <p className="text-gray-900">{fullName}</p>
                            <p className="text-xs text-gray-500">{ticket.profiles?.email || ''}</p>
                            {ticket.contact_number && (
                              <p className="text-xs text-gray-500">{ticket.contact_number}</p>
                            )}
                          </td>
                          <td className="p-3 hidden lg:table-cell">
                            {ticket.order_id ? (
                              <a
                                href={`/dashboard/orders/${ticket.order_id}`}
                                className="text-blue-600 hover:text-blue-800 hover:underline font-mono text-xs"
                                title="View Order Details"
                              >
                                {ticket.order_id.substring(0, 8)}...
                              </a>
                            ) : (
                              <span className="text-gray-400 text-xs">—</span>
                            )}
                          </td>
                          <td className="p-3 hidden lg:table-cell">
                            <span className="px-2 py-1 bg-gray-100 text-gray-700 rounded text-xs">
                              {ticket.category}
                            </span>
                          </td>
                          <td className="p-3 hidden lg:table-cell">
                            <PriorityBadge priority={ticket.priority} />
                          </td>
                          <td className="p-3">
                            <StatusBadge status={ticket.status} />
                          </td>
                          <td className="p-3 text-gray-500 text-xs hidden md:table-cell">
                            {new Date(ticket.created_at).toLocaleDateString()}
                          </td>
                          <td className="p-3">
                            <div className="flex items-center gap-2">
                              <button
                                onClick={() => {
                                  setSelectedTicket(ticket)
                                  setStatusUpdateMessage('')
                                  setPendingStatus(null)
                                  setShowTicketModal(true)
                                }}
                                className="p-1 text-blue-600 hover:bg-blue-50 rounded"
                                title="View Details"
                              >
                                <Eye className="h-4 w-4" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* FAQs Tab */}
      {activeTab === 'faqs' && (
        <div className="space-y-6">
          {/* Header with Add Button */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Frequently Asked Questions</h2>
              <p className="text-sm text-gray-600">Manage FAQs for User App and Vendor App</p>
            </div>
            <Button onClick={() => {
              setEditingFaq(null)
              setFaqForm({
                question: '',
                answer: '',
                category: 'General',
                app_type: faqAppTypeFilter,
                display_order: 0,
                is_active: true
              })
              setShowFaqModal(true)
            }}>
              <Plus className="h-4 w-4 mr-2" />
              Add FAQ
            </Button>
          </div>

          {/* App Type Tabs */}
          <div className="bg-white rounded-lg border border-gray-200 p-1">
            <div className="flex gap-2">
              <button
                onClick={() => setFaqAppTypeFilter('user_app')}
                className={`flex-1 px-4 py-2 text-sm font-medium rounded-md transition-colors ${
                  faqAppTypeFilter === 'user_app'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <div className="flex items-center justify-center gap-2">
                  <Users className="h-4 w-4" />
                  User App FAQs ({faqs.filter(f => f.app_type === 'user_app').length})
                </div>
              </button>
              <button
                onClick={() => setFaqAppTypeFilter('vendor_app')}
                className={`flex-1 px-4 py-2 text-sm font-medium rounded-md transition-colors ${
                  faqAppTypeFilter === 'vendor_app'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <div className="flex items-center justify-center gap-2">
                  <Store className="h-4 w-4" />
                  Vendor App FAQs ({faqs.filter(f => f.app_type === 'vendor_app').length})
                </div>
              </button>
            </div>
          </div>

          {/* Filters */}
          <div className="bg-white p-4 rounded-lg border border-gray-200">
            <div className="flex flex-wrap gap-4 items-center">
              <div className="flex-1 min-w-[200px]">
                <Input
                  placeholder="Search FAQs..."
                  value={faqSearch}
                  onChange={(e) => setFaqSearch(e.target.value)}
                />
              </div>
              <select
                className="h-10 rounded-md border border-input bg-background px-3 text-sm"
                value={faqCategoryFilter}
                onChange={(e) => setFaqCategoryFilter(e.target.value)}
              >
                <option value="all">All categories</option>
                {FAQ_CATEGORIES.map(c => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
              <Button onClick={loadFAQs} disabled={faqsLoading}>
                {faqsLoading ? 'Refreshing...' : 'Refresh'}
              </Button>
            </div>
          </div>

          {/* FAQs List */}
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            {faqsLoading ? (
              <div className="p-8 text-center text-gray-500">Loading FAQs...</div>
            ) : faqsError ? (
              <div className="p-8 text-center text-red-600">{faqsError}</div>
            ) : filteredFAQs.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <HelpCircle className="h-12 w-12 mx-auto text-gray-300 mb-4" />
                <p>No FAQs found for {faqAppTypeFilter === 'user_app' ? 'User App' : 'Vendor App'}</p>
                <p className="text-sm text-gray-400 mt-1">Click "Add FAQ" to create your first FAQ</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-200">
                {filteredFAQs.map((faq) => (
                  <div key={faq.id} className="p-6 hover:bg-gray-50">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-2 flex-wrap">
                          <span className="px-2 py-1 bg-blue-100 text-blue-700 rounded text-xs font-medium">
                            {faq.category}
                          </span>
                          <span className={`px-2 py-1 rounded text-xs font-medium ${
                            faq.app_type === 'user_app' 
                              ? 'bg-green-100 text-green-700' 
                              : 'bg-purple-100 text-purple-700'
                          }`}>
                            {faq.app_type === 'user_app' ? 'User App' : 'Vendor App'}
                          </span>
                          {!faq.is_active && (
                            <span className="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs">
                              Inactive
                            </span>
                          )}
                          <span className="text-xs text-gray-500">
                            Order: {faq.display_order}
                          </span>
                        </div>
                        <h3 className="text-lg font-semibold text-gray-900 mb-2">{faq.question}</h3>
                        <p className="text-gray-700 whitespace-pre-wrap">{faq.answer}</p>
                        <div className="mt-3 flex items-center gap-4 text-xs text-gray-500">
                          <span>Views: {faq.view_count}</span>
                          <span>Helpful: {faq.helpful_count}</span>
                          <span>Not Helpful: {faq.not_helpful_count}</span>
                        </div>
                      </div>
                      <div className="flex items-center gap-2 ml-4">
                        <button
                          onClick={() => editFAQ(faq)}
                          className="p-2 text-blue-600 hover:bg-blue-50 rounded"
                          title="Edit FAQ"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button
                          onClick={() => deleteFAQ(faq.id)}
                          className="p-2 text-red-600 hover:bg-red-50 rounded"
                          title="Delete FAQ"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Ticket Details Modal */}
      {showTicketModal && selectedTicket && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-3xl w-full max-h-[90vh] overflow-y-auto m-4">
            <div className="p-6 border-b border-gray-200 flex items-center justify-between">
              <h2 className="text-xl font-bold text-gray-900">Ticket Details</h2>
              <button
                onClick={() => {
                  setShowTicketModal(false)
                  setSelectedTicket(null)
                  setPendingStatus(null)
                  setStatusUpdateMessage('')
                }}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-6 w-6" />
              </button>
            </div>
            <div className="p-4 lg:p-6 space-y-4 lg:space-y-6">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-700">Status</label>
                  <div className="mt-1">
                    <StatusBadge status={selectedTicket.status} />
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Priority</label>
                  <div className="mt-1">
                    <PriorityBadge priority={selectedTicket.priority} />
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-700">Category</label>
                  <p className="mt-1 text-gray-900">{selectedTicket.category}</p>
                </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Created</label>
                <p className="mt-1 text-gray-900">{new Date(selectedTicket.created_at).toLocaleString()}</p>
              </div>
              {selectedTicket.order_id && (
                <div>
                  <label className="text-sm font-medium text-gray-700">Order ID</label>
                  <p className="mt-1">
                    <a
                      href={`/dashboard/orders/${selectedTicket.order_id}`}
                      className="text-blue-600 hover:text-blue-800 hover:underline font-mono"
                    >
                      {selectedTicket.order_id}
                    </a>
                  </p>
                </div>
              )}
              {selectedTicket.contact_number && (
                <div>
                  <label className="text-sm font-medium text-gray-700">Contact Number</label>
                  <p className="mt-1 text-gray-900">{selectedTicket.contact_number}</p>
                </div>
              )}
            </div>
            
            <div>
              <label className="text-sm font-medium text-gray-700">Subject</label>
              <p className="mt-1 text-gray-900">{selectedTicket.subject}</p>
            </div>
              
              <div>
                <label className="text-sm font-medium text-gray-700">Message</label>
                <p className="mt-1 text-gray-900 whitespace-pre-wrap">
                  {selectedTicket.message || 'No message provided'}
                </p>
              </div>
              
              {selectedTicket.profiles && (
                <div>
                  <label className="text-sm font-medium text-gray-700">Customer Information</label>
                  <div className="mt-1 space-y-1">
                    <p className="text-gray-900">
                      {selectedTicket.profiles.first_name || ''} {selectedTicket.profiles.last_name || ''}
                    </p>
                    <p className="text-gray-600 text-sm">{selectedTicket.profiles.email}</p>
                    {selectedTicket.profiles.phone_number && (
                      <p className="text-gray-600 text-sm">{selectedTicket.profiles.phone_number}</p>
                    )}
                  </div>
                </div>
              )}
              
              <div>
                <label className="text-sm font-medium text-gray-700">Admin Notes</label>
                <textarea
                  className="mt-1 w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                  rows={4}
                  value={selectedTicket.admin_notes || ''}
                  onChange={(e) => {
                    const updated = { ...selectedTicket, admin_notes: e.target.value }
                    setSelectedTicket(updated)
                  }}
                  placeholder="Add internal notes about this ticket..."
                />
                <Button
                  onClick={() => {
                    updateTicketNotes(selectedTicket.id, selectedTicket.admin_notes || '')
                  }}
                  className="mt-2"
                >
                  Save Notes
                </Button>
              </div>
              
              <div className="pt-4 border-t border-gray-200 space-y-3">
                <div className="flex flex-wrap items-center gap-4">
                  <label className="text-sm font-medium text-gray-700">Update Status:</label>
                  <select
                    className="border rounded px-3 py-2 text-sm"
                    value={pendingStatus || selectedTicket.status}
                    onChange={(e) => {
                      const newStatus = e.target.value
                      if (newStatus !== selectedTicket.status) {
                        // Status changed - show message field and set pending status
                        setPendingStatus(newStatus)
                        setStatusUpdateMessage('')
                      } else {
                        // Same status selected - clear pending
                        setPendingStatus(null)
                        setStatusUpdateMessage('')
                      }
                    }}
                  >
                    {STATUSES.map(s => (
                      <option key={s} value={s}>{s.replace('_', ' ')}</option>
                    ))}
                  </select>
                </div>
                {pendingStatus && pendingStatus !== selectedTicket.status && (
                  <div>
                    <label className="text-sm font-medium text-gray-700">
                      Message to customer/vendor <span className="text-red-500">*</span>
                    </label>
                    <textarea
                      className="mt-1 w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                      rows={3}
                      value={statusUpdateMessage}
                      onChange={(e) => setStatusUpdateMessage(e.target.value)}
                      placeholder="Type a message that will be sent as a notification when you update the status..."
                      required
                    />
                    <p className="mt-1 text-xs text-gray-500">
                      This message is required and will be sent as a notification to the {selectedTicket.user_id ? 'customer' : 'vendor'}.
                    </p>
                    <Button
                      onClick={() => {
                        if (!statusUpdateMessage.trim()) {
                          alert('Please enter a message before updating the status.')
                          return
                        }
                        updateTicketStatus(selectedTicket, pendingStatus, statusUpdateMessage)
                      }}
                      className="mt-2"
                      disabled={!statusUpdateMessage.trim()}
                    >
                      Update Status & Send Notification
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => {
                        setPendingStatus(null)
                        setStatusUpdateMessage('')
                      }}
                      className="mt-2 ml-2"
                    >
                      Cancel
                    </Button>
                  </div>
                )}
                {!pendingStatus && (
                  <p className="text-xs text-gray-500">
                    Select a different status to send a notification message to the customer/vendor.
                  </p>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* FAQ Modal */}
      {showFaqModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto m-4">
            <div className="p-6 border-b border-gray-200 flex items-center justify-between">
              <h2 className="text-xl font-bold text-gray-900">
                {editingFaq ? 'Edit FAQ' : 'Add New FAQ'}
              </h2>
              <button
                onClick={() => {
                  setShowFaqModal(false)
                  setEditingFaq(null)
                  setFaqForm({
                    question: '',
                    answer: '',
                    category: 'General',
                    app_type: faqAppTypeFilter,
                    display_order: 0,
                    is_active: true
                  })
                }}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-6 w-6" />
              </button>
            </div>
            <div className="p-4 lg:p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Question *</label>
                <Input
                  value={faqForm.question}
                  onChange={(e) => setFaqForm({ ...faqForm, question: e.target.value })}
                  placeholder="Enter the question..."
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Answer *</label>
                <textarea
                  className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                  rows={6}
                  value={faqForm.answer}
                  onChange={(e) => setFaqForm({ ...faqForm, answer: e.target.value })}
                  placeholder="Enter the answer..."
                />
              </div>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">App Type *</label>
                  <select
                    className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
                    value={faqForm.app_type}
                    onChange={(e) => setFaqForm({ ...faqForm, app_type: e.target.value as 'user_app' | 'vendor_app' })}
                  >
                    <option value="user_app">User App</option>
                    <option value="vendor_app">Vendor App</option>
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
                  <select
                    className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
                    value={faqForm.category}
                    onChange={(e) => setFaqForm({ ...faqForm, category: e.target.value })}
                  >
                    {FAQ_CATEGORIES.map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Display Order</label>
                  <Input
                    type="number"
                    value={faqForm.display_order}
                    onChange={(e) => setFaqForm({ ...faqForm, display_order: parseInt(e.target.value) || 0 })}
                  />
                </div>
              </div>
              
              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="is_active"
                  checked={faqForm.is_active}
                  onChange={(e) => setFaqForm({ ...faqForm, is_active: e.target.checked })}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <label htmlFor="is_active" className="ml-2 text-sm text-gray-700">
                  Active (visible to users)
                </label>
              </div>
              
              <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
                <Button
                  variant="outline"
                  onClick={() => {
                    setShowFaqModal(false)
                    setEditingFaq(null)
                    setFaqForm({
                      question: '',
                      answer: '',
                      category: 'General',
                      app_type: faqAppTypeFilter,
                      display_order: 0,
                      is_active: true
                    })
                  }}
                >
                  Cancel
                </Button>
                <Button onClick={saveFAQ}>
                  {editingFaq ? 'Update FAQ' : 'Create FAQ'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
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
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors[status] || colors.open}`}>
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
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors[priority] || colors.medium}`}>
      {priority}
    </span>
  )
}
