-- Add is_draft column to services table
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'services' 
        AND column_name = 'is_draft'
    ) THEN
        ALTER TABLE public.services 
        ADD COLUMN is_draft boolean DEFAULT false;
        
        RAISE NOTICE 'Added is_draft column to services table';
    ELSE
        RAISE NOTICE 'is_draft column already exists in services table';
    END IF;
END $$;

-- Update index for draft services
CREATE INDEX IF NOT EXISTS idx_services_draft 
ON public.services(is_draft, vendor_id) 
WHERE is_draft = true;
