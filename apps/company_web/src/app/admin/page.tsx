import Link from 'next/link'
import { Button } from '@/components/ui/Button'
import { ProtectedRoute } from '@/components/auth/ProtectedRoute'
import { ArrowRight, Shield, BarChart3, Users, ShoppingBag } from 'lucide-react'

export default function Home() {
  return (
    <ProtectedRoute requireAuth={false}>
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
        {/* Header */}
        <header className="bg-white shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-6">
              <div className="flex items-center">
                <Shield className="h-8 w-8 text-indigo-600 mr-2" />
                <h1 className="text-2xl font-bold text-gray-900">Saral Events Admin</h1>
              </div>
              <div className="flex items-center space-x-4">
                <Link href="/admin/signin">
                  <Button variant="ghost">Sign In</Button>
                </Link>
                <Link href="/admin/signup">
                  <Button>Get Started</Button>
                </Link>
              </div>
            </div>
          </div>
        </header>

        {/* Hero Section */}
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
          <div className="text-center">
            <h1 className="text-4xl md:text-6xl font-bold text-gray-900 mb-6">
              Manage Your Event Business
            </h1>
            <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
              Complete admin dashboard for managing orders, vendors, users, and services. 
              Built for event planning companies who need powerful tools.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link href="/admin/signin">
                <Button size="lg" className="w-full sm:w-auto">
                  Sign In to Dashboard
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
              <Link href="/admin/signup">
                <Button variant="outline" size="lg" className="w-full sm:w-auto">
                  Create Account
                </Button>
              </Link>
            </div>
          </div>

          {/* Features Grid */}
          <div className="mt-20 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            <FeatureCard
              icon={ShoppingBag}
              title="Order Management"
              description="Track and manage all customer orders with real-time updates"
            />
            <FeatureCard
              icon={Users}
              title="User & Vendor Management"
              description="Manage user accounts and vendor profiles efficiently"
            />
            <FeatureCard
              icon={BarChart3}
              title="Analytics & Reports"
              description="Get insights into your business performance with detailed analytics"
            />
            <FeatureCard
              icon={Shield}
              title="Secure & Reliable"
              description="Enterprise-grade security with role-based access control"
            />
          </div>
        </main>

        {/* Footer */}
        <footer className="bg-white border-t border-gray-200 mt-20">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <div className="text-center text-gray-600">
              <p>&copy; 2024 Saral Events. All rights reserved.</p>
            </div>
          </div>
        </footer>
      </div>
    </ProtectedRoute>
  )
}

function FeatureCard({ 
  icon: Icon, 
  title, 
  description 
}: { 
  icon: any
  title: string
  description: string
}) {
  return (
    <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow">
      <div className="flex items-center mb-4">
        <div className="p-3 bg-indigo-50 rounded-lg">
          <Icon className="h-6 w-6 text-indigo-600" />
        </div>
      </div>
      <h3 className="text-lg font-semibold text-gray-900 mb-2">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </div>
  )
}


