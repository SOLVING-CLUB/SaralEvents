-- Fix Refund INSERT Policy
-- This allows users to insert refund records when cancelling bookings
-- Run this in Supabase SQL Editor

-- Users can insert refunds for their own bookings
CREATE POLICY "Users can insert refunds for their bookings" ON refunds
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = refunds.booking_id
      AND b.user_id = auth.uid()
    )
  );

-- Vendors can insert refunds for their bookings (for vendor cancellations)
CREATE POLICY "Vendors can insert refunds for their bookings" ON refunds
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = refunds.booking_id
      AND b.vendor_id IN (
        SELECT id FROM vendor_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Users can insert refund milestones for their refunds
CREATE POLICY "Users can insert refund milestones" ON refund_milestones
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM refunds r
      JOIN bookings b ON r.booking_id = b.id
      WHERE r.id = refund_milestones.refund_id
      AND b.user_id = auth.uid()
    )
  );

-- Vendors can insert refund milestones for their refunds
CREATE POLICY "Vendors can insert refund milestones" ON refund_milestones
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM refunds r
      JOIN bookings b ON r.booking_id = b.id
      WHERE r.id = refund_milestones.refund_id
      AND b.vendor_id IN (
        SELECT id FROM vendor_profiles WHERE user_id = auth.uid()
      )
    )
  );
