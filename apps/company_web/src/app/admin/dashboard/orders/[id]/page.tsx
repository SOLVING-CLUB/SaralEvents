"use client"

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import {
  ArrowLeft,
  RefreshCw,
  CheckCircle,
  Clock,
  DollarSign,
  User,
  Store,
  Calendar,
  MapPin,
  FileText,
  CreditCard,
  AlertCircle,
  Edit,
  Save,
  X
} from 'lucide-react'

type Booking = {
  id: string
  booking_date: string
  booking_time: string | null
  status: string
  amount: number
  notes: string | null
  created_at: string
  updated_at: string
  milestone_status: string | null
  vendor_accepted_at: string | null
  vendor_traveling_at: string | null
  vendor_arrived_at: string | null
  arrival_confirmed_at: string | null
  setup_completed_at: string | null
  setup_confirmed_at: string | null
  completed_at: string | null
  services?: {
    id: string
    name: string
    description: string | null
    price: number
    categories?: {
      name: string
    } | null
  } | null
  vendor_profiles?: {
    id: string
    business_name: string
    email: string | null
    phone_number: string | null
    address: string | null
  } | null
  user_profiles?: {
    user_id: string
    first_name: string | null
    last_name: string | null
    email: string | null
    phone_number: string | null
  } | null
  payment_milestones?: Array<{
    id: string
    milestone_type: string
    percentage: number
    amount: number
    status: string
    escrow_held_at: string | null
    escrow_released_at: string | null
    created_at: string
    escrow_transactions?: Array<{
      id: string
      transaction_type: string
      amount: number
      commission_amount: number
      vendor_amount: number
      status: string
      admin_verified_at: string | null
      notes: string | null
    }>
  }>
}

const COMMISSION_RATE = 0.15
const PAYMENT_GATEWAY_FEE_RATE = 0.02

export default function OrderDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const supabase = createClient()
  const bookingId = params.id as string

  const [booking, setBooking] = useState<Booking | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isEditingStatus, setIsEditingStatus] = useState(false)
  const [newStatus, setNewStatus] = useState('')
  const [statusNote, setStatusNote] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (bookingId) {
      loadBookingDetails()
    }
  }, [bookingId])

  async function loadBookingDetails() {
    setLoading(true)
    setError(null)

    try {
      // First, get the booking with related data
      const { data: bookingData, error: bookingErr } = await supabase
        .from('bookings')
        .select(`
          *,
          services(
            id,
            name,
            description,
            price,
            categories(name)
          ),
          vendor_profiles(
            id,
            business_name,
            email,
            phone_number,
            address
          ),
          payment_milestones(
            *,
            escrow_transactions(*)
          )
        `)
        .eq('id', bookingId)
        .maybeSingle()

      if (bookingErr) throw bookingErr
      if (!bookingData) {
        setError('Booking not found')
        return
      }

      // Then, get user profile separately using user_id
      let userProfile = null
      if (bookingData.user_id) {
        const { data: userData } = await supabase
          .from('user_profiles')
          .select('user_id, first_name, last_name, email, phone_number')
          .eq('user_id', bookingData.user_id)
          .maybeSingle()

        userProfile = userData
      }

      const transformed = {
        ...bookingData,
        user_profiles: userProfile,
        payment_milestones: (bookingData.payment_milestones || []).map((m: any) => ({
          ...m,
          escrow_transactions: m.escrow_transactions || []
        }))
      } as Booking

      setBooking(transformed)
      setNewStatus(transformed.status)
    } catch (err: any) {
      setError(err.message)
    }
    setLoading(false)
  }

  async function updateBookingStatus() {
    if (!booking || newStatus === booking.status) {
      setIsEditingStatus(false)
      return
    }

    setSaving(true)
    try {
      const updateData: any = {
        status: newStatus,
        updated_at: new Date().toISOString()
      }

      // Update milestone status based on new booking status
      if (newStatus === 'vendor_arrived') {
        updateData.vendor_arrived_at = new Date().toISOString()
        updateData.milestone_status = 'vendor_arrived'
      } else if (newStatus === 'arrival_confirmed') {
        updateData.arrival_confirmed_at = new Date().toISOString()
        updateData.milestone_status = 'arrival_confirmed'
      } else if (newStatus === 'setup_completed') {
        updateData.setup_completed_at = new Date().toISOString()
        updateData.milestone_status = 'setup_completed'
      } else if (newStatus === 'setup_confirmed') {
        updateData.setup_confirmed_at = new Date().toISOString()
        updateData.milestone_status = 'setup_confirmed'
      } else if (newStatus === 'completed') {
        updateData.completed_at = new Date().toISOString()
        updateData.milestone_status = 'completed'
      }

      const { error: err } = await supabase
        .from('bookings')
        .update(updateData)
        .eq('id', bookingId)

      if (err) throw err

      // Add note if provided
      if (statusNote.trim()) {
        // You might want to add a notes/activity log table
        console.log('Status note:', statusNote)
      }

      await loadBookingDetails()
      setIsEditingStatus(false)
      setStatusNote('')
      alert('Order status updated successfully')
    } catch (err: any) {
      alert(`Error: ${err.message}`)
    }
    setSaving(false)
  }

  const getStatusColor = (status: string) => {
    const statusLower = status.toLowerCase()
    if (statusLower.includes('completed')) return 'bg-green-100 text-green-700 border-green-300'
    if (statusLower.includes('cancelled')) return 'bg-red-100 text-red-700 border-red-300'
    if (statusLower.includes('confirmed') || statusLower.includes('arrived')) return 'bg-blue-100 text-blue-700 border-blue-300'
    if (statusLower.includes('pending')) return 'bg-yellow-100 text-yellow-700 border-yellow-300'
    return 'bg-gray-100 text-gray-700 border-gray-300'
  }

  const getMilestoneLabel = (type: string) => {
    switch (type) {
      case 'advance': return 'Advance Payment (20%)'
      case 'arrival': return 'Arrival Payment (50%)'
      case 'completion': return 'Completion Payment (30%)'
      default: return type
    }
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return 'Not set'
    return new Date(dateString).toLocaleString('en-IN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <RefreshCw className="h-8 w-8 animate-spin mx-auto mb-4 text-blue-600" />
          <p className="text-gray-600">Loading order details...</p>
        </div>
      </div>
    )
  }

  if (error || !booking) {
    return (
      <div className="p-6">
        <Button variant="outline" onClick={() => router.back()} className="mb-4">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to Orders
        </Button>
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <AlertCircle className="h-12 w-12 text-red-600 mx-auto mb-4" />
          <h2 className="text-xl font-bold text-red-900 mb-2">Error Loading Order</h2>
          <p className="text-red-700">{error || 'Order not found'}</p>
          <Button onClick={loadBookingDetails} className="mt-4">
            <RefreshCw className="h-4 w-4 mr-2" />
            Retry
          </Button>
        </div>
      </div>
    )
  }

  const customerName = booking.user_profiles
    ? `${booking.user_profiles.first_name || ''} ${booking.user_profiles.last_name || ''}`.trim() || 'Customer'
    : 'Customer'

  const totalCommission = booking.payment_milestones?.reduce((sum, m) => {
    if (m.status === 'released' && m.escrow_transactions && m.escrow_transactions.length > 0) {
      return sum + (m.escrow_transactions[0]?.commission_amount || 0)
    }
    return sum + (Number(m.amount) * COMMISSION_RATE)
  }, 0) || 0

  const totalGatewayFee = booking.payment_milestones?.reduce((sum, m) => {
    return sum + (Number(m.amount) * PAYMENT_GATEWAY_FEE_RATE)
  }, 0) || 0

  const totalReleased = booking.payment_milestones?.reduce((sum, m) => {
    if (m.status === 'released' && m.escrow_transactions && m.escrow_transactions.length > 0) {
      return sum + (m.escrow_transactions[0]?.vendor_amount || 0)
    }
    return sum
  }, 0) || 0

  const isConfirmed = booking.status === 'confirmed' || booking.status === 'completed' || booking.status.includes('vendor_') || booking.status.includes('setup_')
  const isPending = booking.status === 'pending'
  const isCompleted = booking.status === 'completed'

  const maskInfo = (info: string | null) => {
    if (!info) return 'N/A'
    if (isPending) {
      if (info.includes('@')) {
        const [user, domain] = info.split('@')
        return `${user[0]}${'*'.repeat(user.length - 1)}@${domain}`
      }
      return `${info.slice(0, 3)}${'*'.repeat(info.length - 3)}`
    }
    return info
  }

  // Financial Calculations
  const grossAmount = Number(booking.amount)
  const commission = grossAmount * COMMISSION_RATE
  const gstOnCommission = commission * 0.18 // 18% GST on platform fee
  const gatewayFee = grossAmount * PAYMENT_GATEWAY_FEE_RATE
  const netPayout = grossAmount - commission - gstOnCommission - gatewayFee

  // Timeline Progress
  const hasAdvancePaid = !!booking.payment_milestones?.some(m => m.milestone_type === 'advance' && (m.status === 'paid' || m.status === 'held_in_escrow' || m.status === 'released'))

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header & Common Actions */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <Button variant="outline" onClick={() => router.back()}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back
          </Button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
              Order #{booking.id.slice(0, 8)}
              <span className={`text-xs px-2 py-0.5 rounded-full border ${getStatusColor(booking.status)}`}>
                {booking.status.toUpperCase()}
              </span>
            </h1>
            <p className="text-sm text-gray-500">Placed on {formatDate(booking.created_at)}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {isPending && (
            <>
              <Button onClick={() => { setNewStatus('confirmed'); setIsEditingStatus(true); }} className="bg-green-600 hover:bg-green-700">Accept Order</Button>
              <Button variant="destructive" onClick={() => { setNewStatus('cancelled'); setIsEditingStatus(true); }}>Reject</Button>
            </>
          )}
          {isConfirmed && !isCompleted && (
            <>
              <Button variant="outline" onClick={() => alert('Contacting customer: ' + customerName)}>Contact Customer</Button>
              <Button onClick={() => { setNewStatus('completed'); setIsEditingStatus(true); }}>Mark Completed</Button>
            </>
          )}
          {isCompleted && (
            <>
              <Button variant="outline">View Review</Button>
              <Button variant="outline">Download Invoice</Button>
            </>
          )}
          <Button variant="ghost" size="sm" onClick={loadBookingDetails} disabled={loading}>
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Details & Breakdown */}
        <div className="lg:col-span-2 space-y-6">

          {/* High-Level Order Timeline */}
          <div className="bg-white rounded-xl border p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-6">Order Journey</h3>
            <div className="relative flex justify-between items-start">
              <TimelineStep
                label="Booking Requested"
                date={booking.created_at}
                active={true}
                icon={FileText}
              />
              <TimelineStep
                label="Vendor Confirmed"
                date={booking.vendor_accepted_at}
                active={!!booking.vendor_accepted_at}
                icon={CheckCircle}
              />
              <TimelineStep
                label="Payment Received"
                date={hasAdvancePaid ? booking.created_at : null}
                active={hasAdvancePaid}
                icon={CreditCard}
              />
              <TimelineStep
                label="Service Completed"
                date={booking.completed_at}
                active={!!booking.completed_at}
                icon={CheckCircle}
              />
            </div>
          </div>

          {/* Customer & Event Snapshot */}
          <div className="bg-white rounded-xl border p-6 shadow-sm">
            <h3 className="text-lg font-bold mb-4">Customer & Event Snapshot</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <div className="flex items-start gap-3">
                  <User className="h-5 w-5 text-blue-500 mt-0.5" />
                  <div>
                    <p className="text-xs text-gray-500 uppercase font-bold">Customer</p>
                    <p className="font-semibold text-gray-900">{customerName}</p>
                    <div className="mt-1 space-y-0.5">
                      <p className="text-sm text-gray-600 truncate">{maskInfo(booking.user_profiles?.email || 'N/A')}</p>
                      <p className="text-sm text-gray-600">{maskInfo(booking.user_profiles?.phone_number || 'N/A')}</p>
                    </div>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <Calendar className="h-5 w-5 text-orange-500 mt-0.5" />
                  <div>
                    <p className="text-xs text-gray-500 uppercase font-bold">Date & Time</p>
                    <p className="font-semibold text-gray-900">{new Date(booking.booking_date).toLocaleDateString()} at {booking.booking_time || 'TBD'}</p>
                  </div>
                </div>
              </div>
              <div className="space-y-4">
                <div className="flex items-start gap-3">
                  <MapPin className="h-5 w-5 text-red-500 mt-0.5" />
                  <div>
                    <p className="text-xs text-gray-500 uppercase font-bold">Event Location</p>
                    <p className="font-semibold text-gray-900 leading-tight">
                      {booking.vendor_profiles?.address || 'To be shared after confirmation'}
                    </p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <FileText className="h-5 w-5 text-gray-500 mt-0.5" />
                  <div>
                    <p className="text-xs text-gray-500 uppercase font-bold">Event Type</p>
                    <p className="font-semibold text-gray-900">{booking.services?.categories?.name || 'General Event'}</p>
                  </div>
                </div>
              </div>
            </div>
            {isPending && (
              <div className="mt-4 p-3 bg-blue-50 border border-blue-100 rounded-lg flex items-center gap-2">
                <AlertCircle className="h-4 w-4 text-blue-600" />
                <p className="text-xs text-blue-700">Contact details and exact location are masked until order is confirmed.</p>
              </div>
            )}
          </div>

          {/* Service & Payments Info (Existing logic refined) */}
          <div className="bg-white rounded-xl border overflow-hidden shadow-sm">
            <div className="p-6 border-b bg-gray-50/50">
              <h3 className="font-bold flex items-center gap-2">
                <FileText className="h-5 w-5 text-gray-400" />
                Service & Payment Milestones
              </h3>
            </div>
            <div className="p-6 space-y-4">
              <div className="flex justify-between items-center p-3 border rounded-lg bg-gray-50">
                <div>
                  <p className="font-bold text-gray-900">{booking.services?.name}</p>
                  <p className="text-xs text-gray-600">Base Price</p>
                </div>
                <p className="text-xl font-bold">₹{Number(booking.services?.price || 0).toLocaleString()}</p>
              </div>
              <div className="space-y-3">
                {booking.payment_milestones?.map(m => (
                  <div key={m.id} className="flex justify-between items-center text-sm p-2 bg-white border-b last:border-0">
                    <div className="flex items-center gap-2">
                      <div className={`h-2 w-2 rounded-full ${m.status === 'released' ? 'bg-green-500' : 'bg-gray-300'}`} />
                      <span className="capitalize">{getMilestoneLabel(m.milestone_type)} ({m.percentage}%)</span>
                    </div>
                    <div className="text-right">
                      <span className="font-semibold">₹{Number(m.amount).toLocaleString()}</span>
                      <p className={`text-[10px] font-bold uppercase ${m.status === 'released' ? 'text-green-600' : 'text-gray-400'}`}>
                        {m.status.replace('_', ' ')}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Earnings Summary & Policies */}
        <div className="space-y-6">
          {/* Earnings Breakdown */}
          <div className="bg-gray-900 rounded-2xl p-6 text-white shadow-xl relative overflow-hidden">
            <div className="absolute top-0 right-0 p-4 opacity-10">
              <DollarSign className="h-16 w-16" />
            </div>
            <h3 className="text-lg font-bold mb-6 flex items-center gap-2">
              <BarChart3 className="h-5 w-5 text-blue-400" />
              Earnings Breakdown
            </h3>
            <div className="space-y-4">
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Total Charged</span>
                <span className="font-bold">₹{grossAmount.toLocaleString()}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Platform Commission (15%)</span>
                <span className="text-red-400">-₹{commission.toLocaleString()}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">GST on Commission (18%)</span>
                <span className="text-red-400">-₹{gstOnCommission.toLocaleString()}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Gateway Fees (2%)</span>
                <span className="text-red-400">-₹{gatewayFee.toLocaleString()}</span>
              </div>
              <div className="pt-4 border-t border-gray-800 flex justify-between items-end">
                <div>
                  <p className="text-xs text-gray-400 font-bold uppercase">Net Payout to Vendor</p>
                  <p className="text-3xl font-bold text-green-400">₹{netPayout.toLocaleString()}</p>
                </div>
                <div className="text-right text-[10px] text-gray-500 italic">
                  *Auto-calculated based on current slabs
                </div>
              </div>
            </div>
          </div>

          {/* Cancellation & Refund Info */}
          <div className="bg-white rounded-xl border p-6 shadow-sm">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <AlertCircle className="h-5 w-5 text-red-500" />
              Cancellation & Refunds
            </h3>
            <div className="space-y-4">
              <div className="p-3 bg-red-50 rounded-lg border border-red-100">
                <p className="text-xs font-bold text-red-800 uppercase mb-1">Cancellation Policy</p>
                <p className="text-sm text-red-900 leading-relaxed">
                  Full refund if cancelled before 48 hours of event. 50% refund after that.
                </p>
              </div>
              <div className="text-sm text-gray-600 space-y-2">
                <p className="font-semibold text-gray-900">Responsibility:</p>
                <ul className="list-disc ml-4 space-y-1">
                  <li>Vendor responsible for full refund if rejected after acceptance.</li>
                  <li>Platform fee is non-refundable for confirmed booking cancellations.</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Hidden Status Editor */}
      {isEditingStatus && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-bold mb-4">Update Order Status to {newStatus.toUpperCase()}</h2>
            <div className="space-y-4">
              <Input
                placeholder="Add a note (visible to admin logs)"
                value={statusNote}
                onChange={(e) => setStatusNote(e.target.value)}
              />
              <div className="flex gap-2">
                <Button onClick={updateBookingStatus} disabled={saving} className="flex-1">
                  {saving ? 'Processing...' : 'Confirm Change'}
                </Button>
                <Button variant="outline" onClick={() => setIsEditingStatus(false)} disabled={saving}>Cancel</Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function TimelineStep({ label, date, active, icon: Icon }: { label: string; date: string | null; active: boolean; icon: any }) {
  return (
    <div className="flex flex-col items-center text-center gap-2 relative z-10 flex-1">
      <div className={`h-10 w-10 rounded-full flex items-center justify-center border-2 transition-all duration-300 ${active ? 'bg-blue-600 border-blue-600 text-white shadow-lg shadow-blue-100' : 'bg-white border-gray-200 text-gray-300'
        }`}>
        <Icon className="h-5 w-5" />
      </div>
      <div className="space-y-0.5 px-2">
        <p className={`text-[10px] font-bold uppercase tracking-tighter ${active ? 'text-blue-700' : 'text-gray-400'}`}>{label}</p>
        {date && <p className="text-[10px] text-gray-500">{new Date(date).toLocaleDateString()}</p>}
      </div>
    </div>
  )
}

function BarChart3(props: any) {
  return (
    <svg
      {...props}
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M3 3v18h18" />
      <path d="M18 17V9" />
      <path d="M13 17V5" />
      <path d="M8 17v-3" />
    </svg>
  )
}

function TimelineItem({ label, date, active }: { label: string; date: string | null; active: boolean }) {
  return (
    <div className="flex items-start gap-3">
      <div className={`mt-1 h-3 w-3 rounded-full ${active ? 'bg-green-500' : 'bg-gray-300'}`} />
      <div className="flex-1">
        <p className={`text-sm font-medium ${active ? 'text-gray-900' : 'text-gray-400'}`}>
          {label}
        </p>
        {date && (
          <p className="text-xs text-gray-500">
            {new Date(date).toLocaleString('en-IN', {
              year: 'numeric',
              month: 'short',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            })}
          </p>
        )}
        {!date && active && (
          <p className="text-xs text-gray-400">Pending</p>
        )}
      </div>
    </div>
  )
}
