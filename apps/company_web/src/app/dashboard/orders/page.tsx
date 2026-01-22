"use client"
import { useEffect, useMemo, useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { useStableSupabase } from '@/hooks/useStableSupabase'
import { useNetworkStatus } from '@/hooks/useNetworkStatus'
import { safeQuery } from '@/lib/api-client'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'

type Booking = {
  id: string
  booking_date: string
  booking_time: string | null
  status: string
  amount: number
  created_at: string
  services?: { name: string } | null
  vendor_profiles?: { business_name: string } | null
}

export default function OrdersPage() {
  const router = useRouter()
  const supabase = useStableSupabase()
  const { isOnline } = useNetworkStatus()
  const abortControllerRef = useRef<AbortController | null>(null)
  const [rows, setRows] = useState<Booking[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // UI state
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'confirmed' | 'completed' | 'cancelled'>('all')
  const [sortBy, setSortBy] = useState<'created_at' | 'booking_date' | 'amount' | 'status'>('created_at')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)

  useEffect(() => {
    // Cancel previous request if still pending
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
    }

    const controller = new AbortController()
    abortControllerRef.current = controller

    const load = async () => {
      if (!isOnline) {
        setError('No internet connection. Please check your network.')
        setLoading(false)
        return
      }

      setLoading(true)
      setError(null)
      
      const { data, error } = await safeQuery(
        async (sb) => {
          return await sb
            .from('bookings')
            .select('id, booking_date, booking_time, status, amount, created_at, services(name), vendor_profiles(business_name)')
            .order('created_at', { ascending: false })
            .limit(200)
        },
        { 
          signal: controller.signal,
          timeout: 30000,
          maxRetries: 3 
        }
      )
      
      // Check if request was cancelled
      if (controller.signal.aborted) {
        return
      }

      if (error) {
        setError(error.message || 'Failed to load orders')
      } else if (data) {
        setRows(data as any)
      }
      setLoading(false)
    }
    
    load()

    return () => {
      controller.abort()
    }
  }, [isOnline])

  // Derived, filtered, and sorted data
  const filtered = useMemo(() => {
    let list = rows
    if (statusFilter !== 'all') {
      list = list.filter(r => (r.status || '').toLowerCase() === statusFilter)
    }
    if (search.trim().length > 0) {
      const q = search.toLowerCase()
      list = list.filter(r =>
        r.id.toLowerCase().includes(q) ||
        (r.services?.name || '').toLowerCase().includes(q) ||
        (r.vendor_profiles?.business_name || '').toLowerCase().includes(q)
      )
    }
    list = [...list].sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1
      if (sortBy === 'created_at' || sortBy === 'booking_date') {
        const av = new Date((a as any)[sortBy] || 0).getTime()
        const bv = new Date((b as any)[sortBy] || 0).getTime()
        return (av - bv) * dir
      }
      if (sortBy === 'amount') {
        const av = Number(a.amount || 0)
        const bv = Number(b.amount || 0)
        return (av - bv) * dir
      }
      if (sortBy === 'status') {
        return ((a.status || '').localeCompare(b.status || '')) * dir
      }
      return 0
    })
    return list
  }, [rows, search, statusFilter, sortBy, sortDir])

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const currentPage = Math.min(page, totalPages)
  const paged = useMemo(() => {
    const start = (currentPage - 1) * pageSize
    return filtered.slice(start, start + pageSize)
  }, [filtered, currentPage, pageSize])

  const toggleSort = (key: typeof sortBy) => {
    if (sortBy === key) {
      setSortDir(prev => (prev === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortBy(key)
      setSortDir('asc')
    }
  }

  const refresh = async () => {
    if (!isOnline) {
      setError('No internet connection. Please check your network.')
      return
    }

    setLoading(true)
    setError(null)
    
    const { data, error } = await safeQuery(
      async (sb) => {
        return await sb
          .from('bookings')
          .select('id, booking_date, booking_time, status, amount, created_at, services(name), vendor_profiles(business_name)')
          .order('created_at', { ascending: false })
          .limit(200)
      },
      { timeout: 30000, maxRetries: 3 }
    )
    
    if (error) {
      setError(error.message || 'Failed to refresh orders')
    } else {
      setRows((data || []) as any)
    }
    setLoading(false)
  }

  const exportCsv = () => {
    const header = ['ID','Service','Vendor','Booking Date','Time','Amount','Status','Created At']
    const lines = [header.join(',')]
    filtered.forEach(b => {
      const line = [
        b.id,
        escapeCsv(b.services?.name ?? ''),
        escapeCsv(b.vendor_profiles?.business_name ?? ''),
        b.booking_date ?? '',
        b.booking_time ?? '',
        String(b.amount ?? ''),
        b.status ?? '',
        b.created_at ?? '',
      ].join(',')
      lines.push(line)
    })
    const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `orders_${new Date().toISOString().slice(0,10)}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  return (
    <main className="p-4 lg:p-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4">
        <h1 className="text-lg lg:text-xl font-semibold">Orders</h1>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={refresh} disabled={loading}>
            {loading ? 'Refreshing...' : 'Refresh'}
          </Button>
          <Button onClick={exportCsv} disabled={loading || filtered.length === 0}>Export CSV</Button>
        </div>
      </div>

      {/* Controls */}
      <div className="bg-white rounded-xl border p-4 mb-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="md:col-span-2">
            <Input
              placeholder="Search by ID, service, vendor"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1) }}
            />
          </div>
          <div>
            <select
              className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
              value={statusFilter}
              onChange={(e) => { setStatusFilter(e.target.value as any); setPage(1) }}
            >
              <option value="all">All statuses</option>
              <option value="pending">Pending</option>
              <option value="confirmed">Confirmed</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          <div>
            <select
              className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
              value={`${sortBy}:${sortDir}`}
              onChange={(e) => {
                const [k, d] = e.target.value.split(':') as [any, any]
                setSortBy(k)
                setSortDir(d)
              }}
            >
              <option value="created_at:desc">Newest first</option>
              <option value="created_at:asc">Oldest first</option>
              <option value="booking_date:asc">Booking date ↑</option>
              <option value="booking_date:desc">Booking date ↓</option>
              <option value="amount:asc">Amount ↑</option>
              <option value="amount:desc">Amount ↓</option>
              <option value="status:asc">Status A-Z</option>
              <option value="status:desc">Status Z-A</option>
            </select>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50 text-left">
            <tr>
              <th className="p-3">ID</th>
              <th className="p-3">Service</th>
              <th className="p-3 hidden md:table-cell">Vendor</th>
              <th className="p-3 cursor-pointer" onClick={() => toggleSort('booking_date')}>
                Date {sortBy === 'booking_date' ? (sortDir === 'asc' ? '↑' : '↓') : ''}
              </th>
              <th className="p-3 hidden lg:table-cell">Time</th>
              <th className="p-3 cursor-pointer" onClick={() => toggleSort('amount')}>
                Amount {sortBy === 'amount' ? (sortDir === 'asc' ? '↑' : '↓') : ''}
              </th>
              <th className="p-3 cursor-pointer" onClick={() => toggleSort('status')}>
                Status {sortBy === 'status' ? (sortDir === 'asc' ? '↑' : '↓') : ''}
              </th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td className="p-3" colSpan={7}>Loading...</td></tr>
            ) : error ? (
              <tr><td className="p-3 text-red-600" colSpan={7}>{error}</td></tr>
            ) : paged.length === 0 ? (
              <tr><td className="p-3" colSpan={7}>No orders</td></tr>
            ) : paged.map(b => (
              <tr 
                key={b.id} 
                className="border-t hover:bg-gray-50 cursor-pointer"
                onClick={() => router.push(`/dashboard/orders/${b.id}`)}
              >
                <td className="p-3 font-mono text-xs break-all select-text">
                  {b.id.slice(0, 8)}...
                </td>
                <td className="p-3">
                  <div>
                    <div>{b.services?.name ?? '-'}</div>
                    <div className="md:hidden text-xs text-gray-500 mt-1">{b.vendor_profiles?.business_name ?? '-'}</div>
                  </div>
                </td>
                <td className="p-3 hidden md:table-cell">{b.vendor_profiles?.business_name ?? '-'}</td>
                <td className="p-3">
                  <div>
                    <div>{b.booking_date}</div>
                    <div className="lg:hidden text-xs text-gray-500 mt-1">{b.booking_time ?? '-'}</div>
                  </div>
                </td>
                <td className="p-3 hidden lg:table-cell">{b.booking_time ?? '-'}</td>
                <td className="p-3 font-semibold">₹{Number(b.amount ?? 0).toFixed(2)}</td>
                <td className="p-3">
                  <StatusPill status={(b.status || '').toLowerCase()} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mt-4">
        <div className="text-sm text-gray-600">
          Showing {(currentPage - 1) * pageSize + Math.min(1, paged.length)}-
          {(currentPage - 1) * pageSize + paged.length} of {filtered.length}
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <select
            className="h-9 rounded-md border border-input bg-background px-2 text-sm"
            value={pageSize}
            onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}
          >
            <option value={10}>10</option>
            <option value={20}>20</option>
            <option value={50}>50</option>
          </select>
          <Button variant="outline" disabled={currentPage === 1} onClick={() => setPage(p => Math.max(1, p - 1))}>Prev</Button>
          <div className="text-sm">Page {currentPage} / {totalPages}</div>
          <Button variant="outline" disabled={currentPage === totalPages} onClick={() => setPage(p => Math.min(totalPages, p + 1))}>Next</Button>
        </div>
      </div>
    </main>
  )
}


function StatusPill({ status }: { status: string }) {
  const map: Record<string, string> = {
    pending: 'bg-yellow-50 text-yellow-700',
    confirmed: 'bg-blue-50 text-blue-700',
    completed: 'bg-green-50 text-green-700',
    cancelled: 'bg-red-50 text-red-700',
  }
  const cls = map[status] || 'bg-gray-100 text-gray-700'
  return (
    <span className={`px-2 py-1 rounded text-xs ${cls}`}>{status || 'unknown'}</span>
  )
}

function escapeCsv(value: string) {
  if (value == null) return ''
  const needsWrap = /[",\n]/.test(value)
  const escaped = value.replace(/"/g, '""')
  return needsWrap ? `"${escaped}"` : escaped
}


