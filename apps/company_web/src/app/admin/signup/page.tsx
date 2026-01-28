import { AuthForm } from '@/components/auth/AuthForm'
import { ProtectedRoute } from '@/components/auth/ProtectedRoute'

export default function SignUpPage() {
  return (
    <ProtectedRoute requireAuth={false}>
      <AuthForm mode="signup" />
    </ProtectedRoute>
  )
}


