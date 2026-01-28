import { redirect } from 'next/navigation'

export default function LegacySigninRedirect() {
  redirect('/admin/signin')
}

