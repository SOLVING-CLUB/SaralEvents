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
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    
    if (error) return { error }

    // Now that we're authenticated, enforce allowlist
    const access = await checkCompanyPortalAccess(email)
    if (!access.ok) {
      await supabase.auth.signOut()
      return { error: { message: access.message } }
    }

    await linkAdminUser()
    await ensureCompanyUserRole()
    await updateAdminUserLastLogin()
    
    return { error: null }
  }

  const signUp = async (email: string, password: string) => {
    const { error } = await supabase.auth.signUp({ email, password })

    const msg = (error?.message || '').toLowerCase()
    if (error && (msg.includes('already registered') || msg.includes('already exists') || msg.includes('user already'))) {
      // User exists; sign in instead
      const { error: signInErr } = await supabase.auth.signInWithPassword({ email, password })
      if (signInErr) return { error: signInErr }
    } else if (error) {
      return { error }
    }

    // Now authenticated, enforce allowlist
    const access = await checkCompanyPortalAccess(email)
    if (!access.ok) {
      await supabase.auth.signOut()
      return { error: { message: access.message } }
    }

    await linkAdminUser()
    await ensureCompanyUserRole()
    await updateAdminUserLastLogin()

    return { error: null }
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
