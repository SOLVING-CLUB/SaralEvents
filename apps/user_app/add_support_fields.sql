-- Add order_id and contact_number fields to support_tickets table
-- Migration: Add Order ID and Contact Number support

-- Add order_id column (nullable, references orders table)
ALTER TABLE support_tickets 
ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES orders(id) ON DELETE SET NULL;

-- Add contact_number column (nullable, for user-provided contact number)
ALTER TABLE support_tickets 
ADD COLUMN IF NOT EXISTS contact_number TEXT;

-- Create index for faster order lookups
CREATE INDEX IF NOT EXISTS idx_support_tickets_order_id ON support_tickets(order_id);

-- Add comment for documentation
COMMENT ON COLUMN support_tickets.order_id IS 'Optional reference to orders table for order-related support requests';
COMMENT ON COLUMN support_tickets.contact_number IS 'User-provided contact number for support communication';
