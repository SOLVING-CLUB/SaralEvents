"use client"

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { 
  LayoutDashboard, 
  ShoppingBag, 
  MessageSquare, 
  Settings, 
  Users, 
  Store, 
  Megaphone,
  BarChart3,
  Star,
  HeadphonesIcon,
  Shield
} from 'lucide-react'

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { name: 'Orders', href: '/dashboard/orders', icon: ShoppingBag },
  { name: 'Services', href: '/dashboard/services', icon: Settings },
  { name: 'Vendors', href: '/dashboard/vendors', icon: Store },
  { name: 'Users', href: '/dashboard/users', icon: Users },
  { name: 'Reviews & Feedback', href: '/dashboard/reviews', icon: Star },
  { name: 'Support Tickets', href: '/dashboard/support', icon: HeadphonesIcon },
  { name: 'Marketing & Promotions', href: '/dashboard/marketing', icon: Megaphone },
  { name: 'Analytics', href: '/dashboard/analytics', icon: BarChart3 },
  { name: 'Access Control', href: '/dashboard/access-control', icon: Shield },
]

export function Sidebar() {
  const pathname = usePathname()

  return (
    <div className="w-64 bg-white border-r border-gray-200 min-h-[calc(100vh-64px)]">
      <nav className="mt-6 px-4">
        <ul className="space-y-1">
          {navigation.map((item) => {
            // For Dashboard, only match exactly; for others, match subpaths too
            const isActive = item.href === '/dashboard' 
              ? pathname === '/dashboard'
              : pathname === item.href || pathname?.startsWith(item.href + '/')
            return (
              <li key={item.name}>
                <Link
                  href={item.href}
                  className={cn(
                    'flex items-center px-3 py-2.5 text-sm font-medium rounded-lg transition-colors',
                    isActive
                      ? 'bg-blue-50 text-blue-700 border-l-4 border-blue-600 -ml-1 pl-4'
                      : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                  )}
                >
                  <item.icon className="h-5 w-5 mr-3 flex-shrink-0" />
                  {item.name}
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>
    </div>
  )
}
