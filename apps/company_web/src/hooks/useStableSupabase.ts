// Hook to get a stable Supabase client reference
import { useMemo } from 'react'
import { createClient } from '@/lib/supabase'

let cachedClient: ReturnType<typeof createClient> | null = null

export function useStableSupabase() {
  return useMemo(() => {
    if (!cachedClient) {
      cachedClient = createClient()
    }
    return cachedClient
  }, [])
}
