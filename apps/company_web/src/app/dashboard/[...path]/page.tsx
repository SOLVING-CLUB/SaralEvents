import { redirect } from 'next/navigation'

export default function LegacyDashboardSubpathRedirect({ params }: { params: { path?: string[] } }) {
  const rest = params?.path?.join('/') ?? ''
  redirect(rest ? `/admin/dashboard/${rest}` : '/admin/dashboard')
}

