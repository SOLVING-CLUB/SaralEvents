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
  Shield,
  XCircle,
  Wallet,
  CreditCard,
  Bell,
  X
} from 'lucide-react'

const navigation = [
  { name: 'Dashboard', href: '/admin/dashboard', icon: LayoutDashboard },
  { name: 'Orders', href: '/admin/dashboard/orders', icon: ShoppingBag },
  { name: 'Payment Milestones', href: '/admin/dashboard/payment-milestones', icon: CreditCard },
  { name: 'Cancellations & Refunds', href: '/admin/dashboard/refunds', icon: XCircle },
  { name: 'Vendor Wallets', href: '/admin/dashboard/vendor-wallets', icon: Wallet },
  { name: 'Services', href: '/admin/dashboard/services', icon: Settings },
  { name: 'Vendors', href: '/admin/dashboard/vendors', icon: Store },
  { name: 'Users', href: '/admin/dashboard/users', icon: Users },
  { name: 'Reviews & Feedback', href: '/admin/dashboard/reviews', icon: Star },
  { name: 'Support Tickets', href: '/admin/dashboard/support', icon: HeadphonesIcon },
  { name: 'Campaigns', href: '/admin/dashboard/campaigns', icon: Bell },
  { name: 'Marketing & Promotions', href: '/admin/dashboard/marketing', icon: Megaphone },
  { name: 'Analytics', href: '/admin/dashboard/analytics', icon: BarChart3 },
  { name: 'Access Control', href: '/admin/dashboard/access-control', icon: Shield },
]

interface SidebarProps {
  onClose?: () => void
}

export function Sidebar({ onClose }: SidebarProps) {
  const pathname = usePathname()

  return (
    <div className="w-64 bg-white border-r border-gray-200 h-full overflow-y-auto">
      {/* Mobile close button */}
      <div className="lg:hidden flex items-center justify-between p-4 border-b border-gray-200">
        <h2 className="text-lg font-semibold text-gray-900">Menu</h2>
        <button
          onClick={onClose}
          className="p-2 text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
          aria-label="Close menu"
        >
          <X className="h-5 w-5" />
        </button>
      </div>
      
      <nav className="mt-6 px-4 pb-6">
        <ul className="space-y-1">
          {navigation.map((item) => {
            // For Dashboard, only match exactly; for others, match subpaths too
            const isActive = item.href === '/admin/dashboard' 
              ? pathname === '/admin/dashboard'
              : pathname === item.href || pathname?.startsWith(item.href + '/')
            return (
              <li key={item.name}>
                <Link
                  href={item.href}
                  onClick={onClose}
                  className={cn(
                    'flex items-center px-3 py-2.5 text-sm font-medium rounded-lg transition-colors',
                    isActive
                      ? 'bg-blue-50 text-blue-700 border-l-4 border-blue-600 -ml-1 pl-4'
                      : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                  )}
                >
                  <item.icon className="h-5 w-5 mr-3 flex-shrink-0" />
                  <span className="truncate">{item.name}</span>
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>
    </div>
  )
}
