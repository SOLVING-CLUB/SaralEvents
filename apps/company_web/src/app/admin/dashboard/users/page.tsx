"use client"
import { useEffect, useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase'
import { Search } from 'lucide-react'

type UserRow = {
  id: string
  email?: string | null
  created_at?: string | null
  user_profiles?: {
    first_name?: string | null
    last_name?: string | null
    phone?: string | null
  } | null
  roles: string[]
}

export default function UsersPage() {
  const supabase = createClient()
  const [rows, setRows] = useState<UserRow[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')

  useEffect(() => {
    const load = async () => {
      setLoading(true)
      try {
        // Fetch user profiles with roles
        const { data, error } = await supabase
          .from('user_profiles')
          .select(`
            user_id, 
            first_name, 
            last_name, 
            phone_number, 
            email, 
            created_at,
            user_roles (role)
          `)
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
            },
            roles: (u.user_roles || []).map((r: any) => r.role)
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

  // Filter users based on search query
  const filteredRows = useMemo(() => {
    if (!searchQuery.trim()) return rows

    const query = searchQuery.toLowerCase().trim()
    return rows.filter(u => {
      const fullName = u.user_profiles
        ? `${u.user_profiles.first_name || ''} ${u.user_profiles.last_name || ''}`.trim().toLowerCase()
        : ''
      const email = (u.email || '').toLowerCase()
      const phone = (u.user_profiles?.phone || '').toLowerCase()
      const userId = (u.id || '').toLowerCase()
      const roles = (u.roles || []).join(' ').toLowerCase()

      return fullName.includes(query) ||
        email.includes(query) ||
        phone.includes(query) ||
        userId.includes(query) ||
        roles.includes(query)
    })
  }, [rows, searchQuery])

  function renderRoleBadge(role: string) {
    const base = "px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider"
    if (role === 'vendor') return <span className={`${base} bg-green-100 text-green-700`}>Vendor</span>
    if (role === 'company') return <span className={`${base} bg-purple-100 text-purple-700`}>Company</span>
    return <span className={`${base} bg-blue-100 text-blue-700`}>User</span>
  }

  return (
    <main className="p-4 lg:p-6">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-lg lg:text-xl font-semibold">Users</h1>
      </div>

      {/* Search Bar */}
      <div className="mb-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
          <input
            type="text"
            placeholder="Search by name, email, role, or user ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
        {searchQuery && (
          <p className="mt-2 text-sm text-gray-600">
            Found {filteredRows.length} user{filteredRows.length !== 1 ? 's' : ''} matching "{searchQuery}"
          </p>
        )}
      </div>

      <div className="bg-white rounded-xl border overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50 text-left">
            <tr>
              <th className="p-3">Name</th>
              <th className="p-3">Roles</th>
              <th className="p-3 hidden md:table-cell">Email</th>
              <th className="p-3 hidden lg:table-cell">Phone</th>
              <th className="p-3 hidden md:table-cell">Joined</th>
              <th className="p-3 hidden lg:table-cell">User ID</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td className="p-3" colSpan={6}>Loading...</td></tr>
            ) : filteredRows.length === 0 ? (
              <tr><td className="p-3" colSpan={6}>
                {searchQuery ? `No users found matching "${searchQuery}"` : 'No users found'}
              </td></tr>
            ) : filteredRows.map(u => {
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
                    </div>
                  </td>
                  <td className="p-3">
                    <div className="flex flex-wrap gap-1">
                      {u.roles.length > 0 ? (
                        u.roles.map(r => <span key={r}>{renderRoleBadge(r)}</span>)
                      ) : (
                        <span className="text-gray-400 italic">None</span>
                      )}
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


