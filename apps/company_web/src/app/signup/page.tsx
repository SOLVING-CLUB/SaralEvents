import { redirect } from 'next/navigation'

export default function LegacySignupRedirect() {
  redirect('/admin/signup')
}

