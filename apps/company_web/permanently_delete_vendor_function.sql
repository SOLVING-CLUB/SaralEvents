-- Enable Realtime for the vendor_profiles table
ALTER TABLE vendor_profiles REPLICA IDENTITY FULL;
begin;
  -- remove the table from the publication if it exists to avoid duplicates
  alter publication supabase_realtime disable table vendor_profiles;
  alter publication supabase_realtime add table vendor_profiles;
commit;

-- Permanent Vendor Account Deletion Function
-- This function deletes all vendor-specific data and optionally the auth account
-- based on whether the user has other roles.

CREATE OR REPLACE FUNCTION permanently_delete_vendor(p_vendor_id UUID, p_user_id UUID)
RETURNS void AS $$
DECLARE
    v_role_count INTEGER;
BEGIN
    -- 1. DELETE VENDOR-SPECIFIC DATA
    -- We delete based on vendor_id and user_id(contextually)
    
    -- Documents and Verification
    DELETE FROM vendor_documents WHERE vendor_id = p_vendor_id;
    
    -- Finance: Wallets, Transactions, Withdrawals
    DELETE FROM wallet_transactions WHERE vendor_id = p_vendor_id;
    DELETE FROM withdrawal_requests WHERE vendor_id = p_vendor_id;
    DELETE FROM vendor_wallets WHERE vendor_id = p_vendor_id;
    
    -- Services and Bookings
    -- Note: Most of these have ON DELETE CASCADE so they'd be gone via vendor_profiles anyway
    DELETE FROM bookings WHERE vendor_id = p_vendor_id;
    DELETE FROM services WHERE vendor_id = p_vendor_id;
    DELETE FROM cart_items WHERE vendor_id = p_vendor_id;
    
    -- Notifications targeted at the vendor role
    DELETE FROM notifications 
    WHERE recipient_vendor_id = p_vendor_id 
       OR (recipient_user_id = p_user_id AND recipient_role = 'VENDOR');

    -- 2. REMOVE THE VENDOR ROLE LINK
    DELETE FROM user_roles WHERE user_id = p_user_id AND role = 'vendor';

    -- 3. DELETE THE VENDOR PROFILE RECORD
    DELETE FROM vendor_profiles WHERE id = p_vendor_id;

    -- 4. CHECK FOR OTHER ROLES (user, company, admin)
    -- This ensures we don't delete the auth account if the user has other identities
    SELECT COUNT(*) INTO v_role_count FROM (
        SELECT 1 FROM user_roles WHERE user_id = p_user_id
        UNION
        SELECT 1 FROM admin_users WHERE user_id = p_user_id
    ) AS all_roles;

    -- 5. CONDITIONAL ACCOUNT DELETION
    IF v_role_count = 0 THEN
        -- The user is ONLY a vendor. Delete their primary account and profile.
        -- Deleting from auth.users cascades to user_profiles due to schema constraints.
        DELETE FROM auth.users WHERE id = p_user_id;
    ELSE
        -- User has other identities (customer/admin). 
        -- Keep their login and primary user_profile, but they are no longer a vendor.
    END IF;

    -- 6. CLEANUP DELETION REQUESTS
    -- We specifically only update the pending ones as "completed"
    -- If they had multiple requests, they are all redundant now.
    UPDATE account_deletion_requests 
    SET status = 'completed', updated_at = NOW() 
    WHERE user_id = p_user_id AND status = 'pending';

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permission to authenticated admins
GRANT EXECUTE ON FUNCTION permanently_delete_vendor(UUID, UUID) TO authenticated;
