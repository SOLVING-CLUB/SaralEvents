"use client"

import { useAuth } from '@/contexts/AuthContext'
import { Header } from './Header'
import { Sidebar } from './Sidebar'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { Menu, X } from 'lucide-react'
import { ToastContainer } from '@/components/ui/ToastContainer'
import { useToast } from '@/hooks/useToast'
import { useRealtimeNotifications } from '@/hooks/useRealtimeNotifications'

interface DashboardLayoutProps {
  children: React.ReactNode
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  const { user, loading } = useAuth()
  const router = useRouter()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const { toasts, removeToast } = useToast()

  // Set up real-time notifications (only when user is authenticated)
  useRealtimeNotifications()

  useEffect(() => {
    // Add timeout to prevent infinite loading
    const timeoutId = setTimeout(() => {
      if (loading) {
        console.warn('Auth loading taking longer than expected')
      }
    }, 10000) // 10 second timeout

    if (!loading && !user) {
      router.push('/admin/signin')
    }

    return () => clearTimeout(timeoutId)
  }, [user, loading, router])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
          <p className="text-sm text-gray-600">Loading...</p>
        </div>
      </div>
    )
  }

  if (!user) {
    return null
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Header onMenuClick={() => setSidebarOpen(!sidebarOpen)} />
      
      {/* Toast Notifications */}
      <ToastContainer toasts={toasts} onRemove={removeToast} />
      
      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}
      
      <div className="flex">
        {/* Sidebar - hidden on mobile, shown on desktop */}
        <div className={`
          fixed lg:static inset-y-0 left-0 z-50
          transform transition-transform duration-300 ease-in-out
          ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
        `}>
          <Sidebar onClose={() => setSidebarOpen(false)} />
        </div>
        
        {/* Main content */}
        <main className="flex-1 p-4 lg:p-6 w-full lg:w-auto">
          {children}
        </main>
      </div>
    </div>
  )
}
