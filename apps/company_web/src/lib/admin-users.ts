/**
 * Admin Users Utility Functions
 * Handles linking auth.users with admin_users table
 */

import { createClient } from '@/lib/supabase'

function normalizeEmail(email: string) {
  return email.trim().toLowerCase()
}

export type CompanyPortalAccessResult =
  | { ok: true; adminUserId: string; role: string; is_active: true }
  | { ok: false; reason: 'not_invited' | 'inactive' | 'table_missing' | 'unknown'; message: string }

/**
 * Company portal access is controlled by `admin_users` allowlist.
 * A Supabase auth user may exist for the same email, but they only gain access to company_web
 * if they have an active row in `admin_users`.
 */
export async function checkCompanyPortalAccess(email: string): Promise<CompanyPortalAccessResult> {
  const supabase = createClient()
  const e = normalizeEmail(email)

  try {
    const { data, error } = await supabase
      .from('admin_users')
      .select('id, role, is_active')
      .eq('email', e)
      .maybeSingle()

    if (error) {
      // 42P01 = undefined_table
      if (error.code === '42P01') {
        return {
          ok: false,
          reason: 'table_missing',
          message: 'Admin access is not configured (admin_users table missing). Run admin_users_schema.sql in Supabase.',
        }
      }
      return { ok: false, reason: 'unknown', message: error.message }
    }

    if (!data) {
      return {
        ok: false,
        reason: 'not_invited',
        message: 'This email is not invited to the Company Admin Portal. Ask the Super Admin to add you in Access Control.',
      }
    }

    if (!data.is_active) {
      return {
        ok: false,
        reason: 'inactive',
        message: 'Your admin access is disabled. Contact the Super Admin.',
      }
    }

    return { ok: true, adminUserId: data.id, role: data.role, is_active: true }
  } catch (err: any) {
    return { ok: false, reason: 'unknown', message: err?.message || 'Failed to validate portal access' }
  }
}

/**
 * Ensure the current authenticated user has a `user_roles` entry for the company portal.
 * This allows the same auth user/email to have separate "accounts" per app without conflicts.
 *
 * If `user_roles` table doesn't exist, this silently no-ops.
 */
export async function ensureCompanyUserRole() {
  const supabase = createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return

  // Try insert; if table doesn't exist, ignore.
  const { error } = await supabase
    .from('user_roles')
    .insert({ user_id: user.id, role: 'company' })

  if (error) {
    // ignore missing table or unique violation
    if (error.code === '42P01' || error.code === '23505') return
    // ignore RLS/permission errors silently (won't block login)
    return
  }
}

/**
 * Link current authenticated user with admin_users table
 * Call this after user signs in to update their user_id
 */
export async function linkAdminUser() {
  const supabase = createClient()
  
  try {
    const { data: { user } } = await supabase.auth.getUser()
    
    if (!user?.email) {
      return { error: null, linked: false }
    }

    // Check if admin_users entry exists for this email
    const { data: adminUser } = await supabase
      .from('admin_users')
      .select('id, user_id')
      .eq('email', normalizeEmail(user.email))
      .maybeSingle()

    if (adminUser && !adminUser.user_id) {
      // Link the user_id
      const { error } = await supabase
        .from('admin_users')
        .update({ 
          user_id: user.id,
          updated_at: new Date().toISOString()
        })
        .eq('id', adminUser.id)

      if (error) {
        console.error('Error linking admin user:', error)
        return { error, linked: false }
      }

      return { error: null, linked: true }
    }

    return { error: null, linked: false }
  } catch (err: any) {
    console.error('Error in linkAdminUser:', err)
    return { error: err, linked: false }
  }
}

/**
 * Update last_login timestamp for admin user
 */
export async function updateAdminUserLastLogin() {
  const supabase = createClient()
  
  try {
    const { data: { user } } = await supabase.auth.getUser()
    
    if (!user?.email) {
      return
    }

    await supabase
      .from('admin_users')
      .update({ 
        last_login: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('email', normalizeEmail(user.email))
  } catch (err) {
    console.error('Error updating last login:', err)
  }
}

/**
 * Check if current user is super admin
 */
export async function isSuperAdmin(): Promise<boolean> {
  const supabase = createClient()
  
  try {
    const { data: { user } } = await supabase.auth.getUser()
    
    if (!user?.email) {
      return false
    }

    const { data } = await supabase
      .from('admin_users')
      .select('role')
      .eq('email', normalizeEmail(user.email))
      .eq('is_active', true)
      .maybeSingle()

    return data?.role === 'super_admin' || user.email === 'admin@saralevents.com'
  } catch (err) {
    console.error('Error checking super admin:', err)
    return false
  }
}

/**
 * Get current user's admin role
 */
export async function getCurrentUserRole(): Promise<string | null> {
  const supabase = createClient()
  
  try {
    const { data: { user } } = await supabase.auth.getUser()
    
    if (!user?.email) {
      return null
    }

    const { data } = await supabase
      .from('admin_users')
      .select('role')
      .eq('email', normalizeEmail(user.email))
      .eq('is_active', true)
      .maybeSingle()

    return data?.role || null
  } catch (err) {
    console.error('Error getting user role:', err)
    return null
  }
}
