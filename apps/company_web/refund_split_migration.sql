-- Migration: Add refund split fields to refunds table
-- This tracks how refunds are split between customer, company, and vendor

-- Add columns for refund split tracking
ALTER TABLE refunds 
ADD COLUMN IF NOT EXISTS company_amount DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS vendor_amount DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS customer_amount DECIMAL(10, 2) DEFAULT 0;

-- Update existing refunds to set customer_amount = refund_amount for backward compatibility
UPDATE refunds 
SET customer_amount = refund_amount 
WHERE customer_amount IS NULL OR customer_amount = 0;

-- Add comment to explain the split
COMMENT ON COLUMN refunds.company_amount IS 'Amount allocated to company (5% of non-refundable amount)';
COMMENT ON COLUMN refunds.vendor_amount IS 'Amount allocated to vendor wallet (95% of non-refundable amount)';
COMMENT ON COLUMN refunds.customer_amount IS 'Amount refunded to customer (refund_amount)';
