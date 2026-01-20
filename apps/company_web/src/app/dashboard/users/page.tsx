"use client"
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'

type UserRow = {
  id: string
  email?: string | null
  created_at?: string | null
  user_profiles?: { 
    first_name?: string | null
    last_name?: string | null
    phone?: string | null
  } | null
}

export default function UsersPage() {
  const supabase = createClient()
  const [rows, setRows] = useState<UserRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      setLoading(true)
      try {
        // Fetch user profiles with all available data
        const { data, error } = await supabase
          .from('user_profiles')
          .select('user_id, first_name, last_name, phone_number, email, created_at')
          .order('created_at', { ascending: false })
          .limit(500)
        
        if (error) {
          console.error('Error fetching users:', error)
          setRows([])
        } else if (data) {
          // Transform the data to match the expected format
          const transformed = data.map((u: any) => ({
            id: u.user_id,
            email: u.email || null,
            created_at: u.created_at || null,
            user_profiles: {
              first_name: u.first_name || null,
              last_name: u.last_name || null,
              phone: u.phone_number || null
            }
          }))
          setRows(transformed)
        } else {
          setRows([])
        }
      } catch (err: any) {
        console.error('Error loading users:', err)
        setRows([])
      }
      setLoading(false)
    }
    load()
  }, [supabase])

  return (
    <main className="p-4 lg:p-6">
      <h1 className="text-lg lg:text-xl font-semibold mb-4">Users</h1>
      <div className="bg-white rounded-xl border overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50 text-left">
            <tr>
              <th className="p-3">Name</th>
              <th className="p-3 hidden md:table-cell">Email</th>
              <th className="p-3 hidden lg:table-cell">Phone</th>
              <th className="p-3 hidden md:table-cell">Joined</th>
              <th className="p-3 hidden lg:table-cell">User ID</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td className="p-3" colSpan={5}>Loading...</td></tr>
            ) : rows.length === 0 ? (
              <tr><td className="p-3" colSpan={5}>No users found</td></tr>
            ) : rows.map(u => {
              const fullName = u.user_profiles 
                ? `${u.user_profiles.first_name || ''} ${u.user_profiles.last_name || ''}`.trim() || 'N/A'
                : 'N/A'
              const joinedDate = u.created_at 
                ? new Date(u.created_at).toLocaleDateString('en-IN', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                  })
                : 'N/A'
              
              return (
                <tr key={u.id} className="border-t hover:bg-gray-50">
                  <td className="p-3 font-medium">
                    <div>
                      <div>{fullName}</div>
                      <div className="md:hidden text-xs text-gray-500 mt-1">
                        {u.email || '-'} • {u.user_profiles?.phone || '-'}
                      </div>
                      <div className="lg:hidden md:block text-xs text-gray-500 mt-1">
                        {joinedDate}
                      </div>
                    </div>
                  </td>
                  <td className="p-3 text-sm hidden md:table-cell">{u.email || '-'}</td>
                  <td className="p-3 text-sm hidden lg:table-cell">{u.user_profiles?.phone || '-'}</td>
                  <td className="p-3 text-sm text-gray-600 hidden md:table-cell">{joinedDate}</td>
                  <td className="p-3 font-mono text-xs text-gray-500 hidden lg:table-cell">{u.id.slice(0, 8)}...</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </main>
  )
}


