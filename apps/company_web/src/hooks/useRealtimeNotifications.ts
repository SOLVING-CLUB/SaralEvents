"use client"

import { useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase'
import { useToast } from './useToast'
import { RealtimeChannel } from '@supabase/supabase-js'

export function useRealtimeNotifications() {
  const { showSuccess, showInfo, showWarning } = useToast()
  const supabase = createClient()
  const channelsRef = useRef<RealtimeChannel[]>([])

  useEffect(() => {
    const channels: RealtimeChannel[] = []
    channelsRef.current = channels

    // ============================================
    // BOOKINGS (ORDERS) NOTIFICATIONS
    // ============================================
    
    // New order creation
    const bookingsChannel = supabase
      .channel('bookings-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'bookings',
        },
        (payload) => {
          const booking = payload.new as any
          const amount = Number(booking.amount || 0).toFixed(2)
          const orderId = booking.id ? booking.id.slice(0, 8) : 'N/A'
          showSuccess(
            'New Order Created',
            `Order #${orderId} for ₹${amount}`
          )
        }
      )
      // Order completion
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'bookings',
          filter: 'status=eq.completed',
        },
        (payload) => {
          const booking = payload.new as any
          const oldBooking = payload.old as any
          if (oldBooking?.status !== 'completed' && booking.status === 'completed') {
            const orderId = booking.id ? booking.id.slice(0, 8) : 'N/A'
            showSuccess(
              'Order Completed',
              `Order #${orderId} has been completed`
            )
          }
        }
      )
      // Order cancellation
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'bookings',
          filter: 'status=eq.cancelled',
        },
        (payload) => {
          const booking = payload.new as any
          const oldBooking = payload.old as any
          if (oldBooking?.status !== 'cancelled' && booking.status === 'cancelled') {
            const orderId = booking.id ? booking.id.slice(0, 8) : 'N/A'
            showWarning(
              'Order Cancelled',
              `Order #${orderId} has been cancelled`
            )
          }
        }
      )
      .subscribe()

    channels.push(bookingsChannel)

    // ============================================
    // SERVICES NOTIFICATIONS
    // ============================================
    
    // New service created by vendor
    const servicesChannel = supabase
      .channel('services-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'services',
        },
        (payload) => {
          const service = payload.new as any
          showInfo(
            'New Service Created',
            `${service.name || 'New service'} by vendor`
          )
        }
      )
      // Service updated
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'services',
        },
        (payload) => {
          const service = payload.new as any
          const oldService = payload.old as any
          // Only notify on significant changes
          if (oldService?.is_visible_to_users !== service.is_visible_to_users) {
            showInfo(
              'Service Visibility Changed',
              `${service.name || 'Service'} is now ${service.is_visible_to_users ? 'visible' : 'hidden'}`
            )
          }
        }
      )
      .subscribe()

    channels.push(servicesChannel)

    // ============================================
    // PAYMENT MILESTONES NOTIFICATIONS
    // ============================================
    
    // Payment milestone held in escrow (needs admin verification)
    const milestonesChannel = supabase
      .channel('payment-milestones-changes')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'payment_milestones',
          filter: 'status=eq.held_in_escrow',
        },
        (payload) => {
          const milestone = payload.new as any
          const oldMilestone = payload.old as any
          if (oldMilestone?.status !== 'held_in_escrow' && milestone.status === 'held_in_escrow') {
            const amount = Number(milestone.amount || 0).toFixed(2)
            showInfo(
              'Payment Held in Escrow',
              `₹${amount} milestone awaiting admin verification`
            )
          }
        }
      )
      // Payment milestone released to vendor
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'payment_milestones',
          filter: 'status=eq.released',
        },
        (payload) => {
          const milestone = payload.new as any
          const oldMilestone = payload.old as any
          if (oldMilestone?.status !== 'released' && milestone.status === 'released') {
            const amount = Number(milestone.amount || 0).toFixed(2)
            showSuccess(
              'Payment Released',
              `₹${amount} milestone released to vendor wallet`
            )
          }
        }
      )
      .subscribe()

    channels.push(milestonesChannel)

    // ============================================
    // WITHDRAWAL REQUESTS NOTIFICATIONS
    // ============================================
    
    // New withdrawal request
    const withdrawalsChannel = supabase
      .channel('withdrawal-requests-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'withdrawal_requests',
        },
        (payload) => {
          const withdrawal = payload.new as any
          const amount = Number(withdrawal.amount || 0).toFixed(2)
          showInfo(
            'New Withdrawal Request',
            `₹${amount} withdrawal request from vendor`
          )
        }
      )
      // Withdrawal approved
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'withdrawal_requests',
          filter: 'status=eq.approved',
        },
        (payload) => {
          const withdrawal = payload.new as any
          const oldWithdrawal = payload.old as any
          if (oldWithdrawal?.status !== 'approved' && withdrawal.status === 'approved') {
            const amount = Number(withdrawal.amount || 0).toFixed(2)
            showSuccess(
              'Withdrawal Approved',
              `₹${amount} withdrawal has been approved`
            )
          }
        }
      )
      // Withdrawal rejected
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'withdrawal_requests',
          filter: 'status=eq.rejected',
        },
        (payload) => {
          const withdrawal = payload.new as any
          const oldWithdrawal = payload.old as any
          if (oldWithdrawal?.status !== 'rejected' && withdrawal.status === 'rejected') {
            const amount = Number(withdrawal.amount || 0).toFixed(2)
            showWarning(
              'Withdrawal Rejected',
              `₹${amount} withdrawal request was rejected`
            )
          }
        }
      )
      .subscribe()

    channels.push(withdrawalsChannel)

    // ============================================
    // REFUNDS NOTIFICATIONS
    // ============================================
    
    // New refund request
    const refundsChannel = supabase
      .channel('refunds-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'refunds',
        },
        (payload) => {
          const refund = payload.new as any
          const amount = Number(refund.refund_amount || 0).toFixed(2)
          const cancelledBy = refund.cancelled_by === 'customer' ? 'Customer' : 'Vendor'
          showWarning(
            'New Refund Request',
            `₹${amount} refund requested by ${cancelledBy}`
          )
        }
      )
      // Refund completed
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'refunds',
          filter: 'status=eq.completed',
        },
        (payload) => {
          const refund = payload.new as any
          const oldRefund = payload.old as any
          if (oldRefund?.status !== 'completed' && refund.status === 'completed') {
            const amount = Number(refund.refund_amount || 0).toFixed(2)
            showSuccess(
              'Refund Processed',
              `₹${amount} refund has been completed`
            )
          }
        }
      )
      .subscribe()

    channels.push(refundsChannel)

    // ============================================
    // VENDOR ACCOUNTS NOTIFICATIONS
    // ============================================
    
    // New vendor account creation
    const vendorsChannel = supabase
      .channel('vendors-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'vendor_profiles',
        },
        (payload) => {
          const vendor = payload.new as any
          showInfo(
            'New Vendor Account',
            `${vendor.business_name || 'New vendor'} has joined the platform`
          )
        }
      )
      // Vendor verification status changes
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'vendor_profiles',
        },
        (payload) => {
          const vendor = payload.new as any
          const oldVendor = payload.old as any
          // Notify on verification status changes
          if (oldVendor?.is_verified !== vendor.is_verified) {
            showInfo(
              'Vendor Verification Updated',
              `${vendor.business_name || 'Vendor'} verification: ${vendor.is_verified ? 'Verified' : 'Unverified'}`
            )
          }
        }
      )
      .subscribe()

    channels.push(vendorsChannel)

    // ============================================
    // USER ACCOUNTS NOTIFICATIONS
    // ============================================
    
    // New user account creation
    const usersChannel = supabase
      .channel('users-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'user_profiles',
        },
        (payload) => {
          const user = payload.new as any
          const userName = user.first_name 
            ? `${user.first_name} ${user.last_name || ''}`.trim()
            : user.email || 'New user'
          showInfo(
            'New User Account',
            `${userName} has joined the platform`
          )
        }
      )
      .subscribe()

    channels.push(usersChannel)

    // ============================================
    // SUPPORT TICKETS NOTIFICATIONS
    // ============================================
    
    // New support ticket creation
    const ticketsChannel = supabase
      .channel('support-tickets-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_tickets',
        },
        (payload) => {
          const ticket = payload.new as any
          const priority = ticket.priority || 'medium'
          const priorityEmoji = priority === 'urgent' ? '🚨' : priority === 'high' ? '⚠️' : ''
          showInfo(
            `New Support Ticket ${priorityEmoji}`,
            `${ticket.subject || 'Support request'} - ${ticket.category || 'General'}`
          )
        }
      )
      // Support ticket resolved
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'support_tickets',
          filter: 'status=eq.resolved',
        },
        (payload) => {
          const ticket = payload.new as any
          const oldTicket = payload.old as any
          if (oldTicket?.status !== 'resolved' && ticket.status === 'resolved') {
            showSuccess(
              'Support Ticket Resolved',
              `${ticket.subject || 'Ticket'} has been resolved`
            )
          }
        }
      )
      .subscribe()

    channels.push(ticketsChannel)

    // ============================================
    // REVIEWS NOTIFICATIONS (if reviews table exists)
    // ============================================
    
    // New review submitted
    const reviewsChannel = supabase
      .channel('reviews-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'reviews',
        },
        (payload) => {
          const review = payload.new as any
          const rating = review.rating || 0
          const stars = '⭐'.repeat(Math.floor(rating))
          showInfo(
            'New Review Submitted',
            `${stars} ${rating}-star review received`
          )
        }
      )
      .subscribe()

    channels.push(reviewsChannel)

    // Cleanup: unsubscribe from all channels on unmount
    return () => {
      channels.forEach((channel) => {
        supabase.removeChannel(channel)
      })
      channelsRef.current = []
    }
  }, [supabase, showSuccess, showInfo, showWarning])
}
