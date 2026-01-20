"use client"

import { createContext, useContext, useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { User, Session } from '@supabase/supabase-js'
import { checkCompanyPortalAccess, ensureCompanyUserRole, linkAdminUser, updateAdminUserLastLogin } from '@/lib/admin-users'

interface AuthContextType {
  user: User | null
  session: Session | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<{ error: any }>
  signUp: (email: string, password: string) => Promise<{ error: any }>
  signOut: () => Promise<void>
  resetPassword: (email: string) => Promise<{ error: any }>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const supabase = createClient()

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setUser(session?.user ?? null)
      setLoading(false)
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      setSession(session)
      setUser(session?.user ?? null)
      setLoading(false)
      
      // Link admin user and update last login when user signs in
      if (event === 'SIGNED_IN' && session?.user) {
        await linkAdminUser()
        await updateAdminUserLastLogin()
      }
    })

    return () => subscription.unsubscribe()
  }, [supabase.auth])

  const signIn = async (email: string, password: string) => {
    // Company portal is allowlist-based: only emails present (and active) in admin_users can sign in.
    const access = await checkCompanyPortalAccess(email)
    if (!access.ok) {
      return { error: { message: access.message } }
    }

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    
    // Link admin user and update last login after successful sign in
    if (!error) {
      await linkAdminUser()
      await ensureCompanyUserRole()
      await updateAdminUserLastLogin()
    }
    
    return { error }
  }

  const signUp = async (email: string, password: string) => {
    // Company portal sign-up is also allowlist-based (invited admins only).
    const access = await checkCompanyPortalAccess(email)
    if (!access.ok) {
      return { error: { message: access.message } }
    }

    const { error } = await supabase.auth.signUp({ email, password })

    // If the auth user already exists (shared across apps), treat this as "sign in instead"
    // so the same email can have separate app accounts without conflicts.
    const msg = (error?.message || '').toLowerCase()
    if (error && (msg.includes('already registered') || msg.includes('already exists') || msg.includes('user already'))) {
      const { error: signInErr } = await supabase.auth.signInWithPassword({ email, password })
      if (!signInErr) {
        await linkAdminUser()
        await ensureCompanyUserRole()
        await updateAdminUserLastLogin()
        return { error: null }
      }
      return { error: signInErr }
    }

    // If sign-up succeeded and session is created immediately, link role/table.
    if (!error) {
      await linkAdminUser()
      await ensureCompanyUserRole()
      await updateAdminUserLastLogin()
    }

    return { error }
  }

  const signOut = async () => {
    // Explicitly sign out and clear local state to avoid sticky sessions
    await supabase.auth.signOut()
    setUser(null)
    setSession(null)
  }

  const resetPassword = async (email: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    return { error }
  }

  const value = {
    user,
    session,
    loading,
    signIn,
    signUp,
    signOut,
    resetPassword,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
