import { redirect } from 'next/navigation'

export default function LegacyResetPasswordRedirect() {
  redirect('/admin/reset-password')
}

