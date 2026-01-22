-- Vendor Setup Database Schema
-- Run this in your Supabase SQL Editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create vendor_profiles table
CREATE TABLE IF NOT EXISTS vendor_profiles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    business_name TEXT NOT NULL,
    address TEXT NOT NULL,
    category TEXT NOT NULL,
    phone_number TEXT,
    email TEXT,
    website TEXT,
    description TEXT,
    services TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create vendor_documents table
CREATE TABLE IF NOT EXISTS vendor_documents (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    vendor_id UUID REFERENCES vendor_profiles(id) ON DELETE CASCADE NOT NULL,
    document_type TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_url TEXT NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_vendor_profiles_user_id ON vendor_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_vendor_documents_vendor_id ON vendor_documents(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_documents_type ON vendor_documents(document_type);

-- Create RLS (Row Level Security) policies
ALTER TABLE vendor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_documents ENABLE ROW LEVEL SECURITY;

-- Bank / KYC fields
ALTER TABLE vendor_profiles
ADD COLUMN IF NOT EXISTS account_holder_name TEXT,
ADD COLUMN IF NOT EXISTS account_number TEXT,
ADD COLUMN IF NOT EXISTS ifsc_code TEXT,
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS branch_name TEXT,
ADD COLUMN IF NOT EXISTS pan_number TEXT,
ADD COLUMN IF NOT EXISTS gst_number TEXT,
ADD COLUMN IF NOT EXISTS aadhaar_number TEXT;

-- Policy: Users can only see their own vendor profile
CREATE POLICY "Users can view own vendor profile" ON vendor_profiles
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own vendor profile
CREATE POLICY "Users can insert own vendor profile" ON vendor_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own vendor profile
CREATE POLICY "Users can update own vendor profile" ON vendor_profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own vendor profile
CREATE POLICY "Users can delete own vendor profile" ON vendor_profiles
    FOR DELETE USING (auth.uid() = user_id);

-- Policy: Users can view documents for their own vendor profile
CREATE POLICY "Users can view own vendor documents" ON vendor_documents
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendor_profiles 
            WHERE id = vendor_documents.vendor_id 
            AND user_id = auth.uid()
        )
    );

-- Policy: Users can insert documents for their own vendor profile
CREATE POLICY "Users can insert own vendor documents" ON vendor_documents
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM vendor_profiles 
            WHERE id = vendor_documents.vendor_id 
            AND user_id = auth.uid()
        )
    );

-- Policy: Users can delete documents for their own vendor profile
CREATE POLICY "Users can delete own vendor documents" ON vendor_documents
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM vendor_profiles 
            WHERE id = vendor_documents.vendor_id 
            AND user_id = auth.uid()
        )
    );

-- Create storage bucket for vendor documents
INSERT INTO storage.buckets (id, name, public) 
VALUES ('vendor_documents', 'vendor_documents', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policy: Users can upload documents to their own folder
CREATE POLICY "Users can upload own vendor documents" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'vendor_documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage policy: Users can view documents in their own folder
CREATE POLICY "Users can view own vendor documents" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'vendor_documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage policy: Users can delete documents in their own folder
CREATE POLICY "Users can delete own vendor documents" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'vendor_documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_vendor_profiles_updated_at ON vendor_profiles;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'update_vendor_profiles_updated_at'
    ) THEN
        CREATE TRIGGER update_vendor_profiles_updated_at 
            BEFORE UPDATE ON vendor_profiles 
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END;
$$;

-- Insert some sample categories (optional)
INSERT INTO vendor_profiles (user_id, business_name, address, category, services) 
VALUES 
    ('00000000-0000-0000-0000-000000000000', 'Sample Venue', 'Sample Address', 'Venue', ARRAY['Wedding Venue', 'Corporate Events']),
    ('00000000-0000-0000-0000-000000000001', 'Sample Catering', 'Sample Address', 'Catering', ARRAY['Wedding Catering', 'Corporate Catering'])
ON CONFLICT (user_id) DO NOTHING;
