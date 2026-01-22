-- Ensure vendor_profiles updated_at trigger exists without duplicate errors
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
