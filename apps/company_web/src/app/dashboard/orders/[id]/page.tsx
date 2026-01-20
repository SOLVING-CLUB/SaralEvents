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

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="outline" onClick={() => router.back()}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back
          </Button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Order Details</h1>
            <p className="text-sm text-gray-600 font-mono">{booking.id}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={loadBookingDetails} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
      </div>

      {/* Status Card */}
      <div className={`bg-white rounded-lg border-2 p-6 ${getStatusColor(booking.status)}`}>
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <h2 className="text-xl font-bold">Order Status</h2>
              {!isEditingStatus && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setIsEditingStatus(true)}
                >
                  <Edit className="h-3 w-3 mr-1" />
                  Edit
                </Button>
              )}
            </div>
            {isEditingStatus ? (
              <div className="space-y-3 mt-4">
                <select
                  className="w-full h-10 rounded-md border border-input bg-white px-3 text-sm"
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value)}
                >
                  <option value="pending">Pending</option>
                  <option value="confirmed">Confirmed</option>
                  <option value="vendor_traveling">Vendor Traveling</option>
                  <option value="vendor_arrived">Vendor Arrived</option>
                  <option value="arrival_confirmed">Arrival Confirmed</option>
                  <option value="setup_completed">Setup Completed</option>
                  <option value="setup_confirmed">Setup Confirmed</option>
                  <option value="completed">Completed</option>
                  <option value="cancelled">Cancelled</option>
                </select>
                <Input
                  placeholder="Add a note (optional)"
                  value={statusNote}
                  onChange={(e) => setStatusNote(e.target.value)}
                />
                <div className="flex gap-2">
                  <Button onClick={updateBookingStatus} disabled={saving}>
                    <Save className="h-3 w-3 mr-1" />
                    {saving ? 'Saving...' : 'Save'}
                  </Button>
                  <Button variant="outline" onClick={() => {
                    setIsEditingStatus(false)
                    setNewStatus(booking.status)
                    setStatusNote('')
                  }}>
                    <X className="h-3 w-3 mr-1" />
                    Cancel
                  </Button>
                </div>
              </div>
            ) : (
              <p className="text-lg font-semibold">{booking.status.toUpperCase()}</p>
            )}
          </div>
          <div className="text-right">
            <p className="text-sm opacity-75">Total Amount</p>
            <p className="text-3xl font-bold">₹{Number(booking.amount).toFixed(2)}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column - Main Info */}
        <div className="lg:col-span-2 space-y-6">
          {/* Service Information */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <FileText className="h-5 w-5" />
              Service Information
            </h3>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-gray-600">Service Name</p>
                <p className="font-semibold">{booking.services?.name || 'N/A'}</p>
              </div>
              {booking.services?.categories?.name && (
                <div>
                  <p className="text-sm text-gray-600">Category</p>
                  <p className="font-semibold">{booking.services.categories.name}</p>
                </div>
              )}
              {booking.services?.description && (
                <div>
                  <p className="text-sm text-gray-600">Description</p>
                  <p className="text-sm">{booking.services.description}</p>
                </div>
              )}
              <div>
                <p className="text-sm text-gray-600">Service Price</p>
                <p className="font-semibold">₹{Number(booking.services?.price || 0).toFixed(2)}</p>
              </div>
            </div>
          </div>

          {/* Customer Information */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <User className="h-5 w-5" />
              Customer Information
            </h3>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-gray-600">Name</p>
                <p className="font-semibold">{customerName}</p>
              </div>
              {booking.user_profiles?.email && (
                <div>
                  <p className="text-sm text-gray-600">Email</p>
                  <p className="text-sm">{booking.user_profiles.email}</p>
                </div>
              )}
              {booking.user_profiles?.phone_number && (
                <div>
                  <p className="text-sm text-gray-600">Phone</p>
                  <p className="text-sm">{booking.user_profiles.phone_number}</p>
                </div>
              )}
            </div>
          </div>

          {/* Vendor Information */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <Store className="h-5 w-5" />
              Vendor Information
            </h3>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-gray-600">Business Name</p>
                <p className="font-semibold">{booking.vendor_profiles?.business_name || 'N/A'}</p>
              </div>
              {booking.vendor_profiles?.email && (
                <div>
                  <p className="text-sm text-gray-600">Email</p>
                  <p className="text-sm">{booking.vendor_profiles.email}</p>
                </div>
              )}
              {booking.vendor_profiles?.phone_number && (
                <div>
                  <p className="text-sm text-gray-600">Phone</p>
                  <p className="text-sm">{booking.vendor_profiles.phone_number}</p>
                </div>
              )}
              {booking.vendor_profiles?.address && (
                <div>
                  <p className="text-sm text-gray-600">Address</p>
                  <p className="text-sm">{booking.vendor_profiles.address}</p>
                </div>
              )}
            </div>
          </div>

          {/* Payment Milestones */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <CreditCard className="h-5 w-5" />
              Payment Milestones
            </h3>
            <div className="space-y-4">
              {booking.payment_milestones?.map((milestone) => {
                const grossAmount = Number(milestone.amount)
                const commissionAmount = grossAmount * COMMISSION_RATE
                const gatewayFee = grossAmount * PAYMENT_GATEWAY_FEE_RATE
                const vendorAmount = grossAmount - commissionAmount - gatewayFee
                const escrowTxn = milestone.escrow_transactions?.[0]
                const isReleased = milestone.status === 'released'

                return (
                  <div key={milestone.id} className="border rounded-lg p-4">
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <p className="font-semibold">{getMilestoneLabel(milestone.milestone_type)}</p>
                        <p className="text-sm text-gray-600">{milestone.percentage}% of total</p>
                      </div>
                      <div className="text-right">
                        <p className="text-lg font-bold text-green-600">₹{grossAmount.toFixed(2)}</p>
                        <span className={`px-2 py-1 rounded text-xs ${getStatusColor(milestone.status)}`}>
                          {milestone.status.replace('_', ' ').toUpperCase()}
                        </span>
                      </div>
                    </div>
                    {isReleased && escrowTxn && (
                      <div className="mt-3 pt-3 border-t space-y-1 text-sm">
                        <div className="flex justify-between">
                          <span className="text-gray-600">Gross Amount:</span>
                          <span className="font-medium">₹{grossAmount.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-gray-600">Commission ({COMMISSION_RATE * 100}%):</span>
                          <span className="font-medium text-red-600">-₹{escrowTxn.commission_amount.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-gray-600">Gateway Fee ({PAYMENT_GATEWAY_FEE_RATE * 100}%):</span>
                          <span className="font-medium text-red-600">-₹{gatewayFee.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between font-bold pt-2 border-t">
                          <span>Vendor Receives:</span>
                          <span className="text-green-600">₹{escrowTxn.vendor_amount.toFixed(2)}</span>
                        </div>
                        {escrowTxn.admin_verified_at && (
                          <p className="text-xs text-gray-500 mt-2">
                            Released: {formatDate(escrowTxn.admin_verified_at)}
                          </p>
                        )}
                      </div>
                    )}
                    {milestone.escrow_held_at && !isReleased && (
                      <p className="text-xs text-gray-500 mt-2">
                        Held in escrow since: {formatDate(milestone.escrow_held_at)}
                      </p>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
        </div>

        {/* Right Column - Timeline & Summary */}
        <div className="space-y-6">
          {/* Order Timeline */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <Clock className="h-5 w-5" />
              Order Timeline
            </h3>
            <div className="space-y-4">
              <TimelineItem
                label="Order Created"
                date={booking.created_at}
                active={true}
              />
              <TimelineItem
                label="Vendor Accepted"
                date={booking.vendor_accepted_at}
                active={!!booking.vendor_accepted_at}
              />
              <TimelineItem
                label="Vendor Traveling"
                date={booking.vendor_traveling_at}
                active={!!booking.vendor_traveling_at}
              />
              <TimelineItem
                label="Vendor Arrived"
                date={booking.vendor_arrived_at}
                active={!!booking.vendor_arrived_at}
              />
              <TimelineItem
                label="Arrival Confirmed"
                date={booking.arrival_confirmed_at}
                active={!!booking.arrival_confirmed_at}
              />
              <TimelineItem
                label="Setup Completed"
                date={booking.setup_completed_at}
                active={!!booking.setup_completed_at}
              />
              <TimelineItem
                label="Setup Confirmed"
                date={booking.setup_confirmed_at}
                active={!!booking.setup_confirmed_at}
              />
              <TimelineItem
                label="Order Completed"
                date={booking.completed_at}
                active={!!booking.completed_at}
              />
            </div>
          </div>

          {/* Payment Summary */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <DollarSign className="h-5 w-5" />
              Payment Summary
            </h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-600">Total Booking Amount:</span>
                <span className="font-semibold">₹{Number(booking.amount).toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Total Commission:</span>
                <span className="font-semibold text-red-600">₹{totalCommission.toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Total Gateway Fees:</span>
                <span className="font-semibold text-red-600">₹{totalGatewayFee.toFixed(2)}</span>
              </div>
              <div className="flex justify-between pt-2 border-t font-bold">
                <span>Total Released to Vendor:</span>
                <span className="text-green-600">₹{totalReleased.toFixed(2)}</span>
              </div>
            </div>
          </div>

          {/* Event Details */}
          <div className="bg-white rounded-lg border p-6">
            <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
              <Calendar className="h-5 w-5" />
              Event Details
            </h3>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-gray-600">Booking Date</p>
                <p className="font-semibold">{new Date(booking.booking_date).toLocaleDateString('en-IN', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric'
                })}</p>
              </div>
              {booking.booking_time && (
                <div>
                  <p className="text-sm text-gray-600">Booking Time</p>
                  <p className="font-semibold">{booking.booking_time}</p>
                </div>
              )}
            </div>
          </div>

          {/* Notes */}
          {booking.notes && (
            <div className="bg-white rounded-lg border p-6">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <FileText className="h-5 w-5" />
                Notes
              </h3>
              <p className="text-sm text-gray-700 whitespace-pre-wrap">{booking.notes}</p>
            </div>
          )}
        </div>
      </div>
    </div>
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
