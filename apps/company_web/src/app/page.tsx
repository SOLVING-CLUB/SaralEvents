import LandingPage from '@/components/landing/LandingPage'
import { Suspense } from 'react'

export default function HomePage() {
  return (
    <Suspense fallback={null}>
      <LandingPage />
    </Suspense>
  )
}
