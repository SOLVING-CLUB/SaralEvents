"use client"
import { useEffect, useMemo, useState, useCallback, useRef } from 'react'
import Image from 'next/image'
import { useStableSupabase } from '@/hooks/useStableSupabase'
import { useNetworkStatus } from '@/hooks/useNetworkStatus'
import { safeQuery } from '@/lib/api-client'
import { Input } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { ChevronRight, Search as SearchIcon, X as XIcon, ArrowUpDown, Filter, X } from 'lucide-react'

type ServiceRow = {
  id: string
  name: string
  price: number | null
  is_active: boolean
  is_visible_to_users: boolean | null
  category?: string | null
  category_id?: string | null
  tags?: string[] | null
  media_urls?: string[] | null
  vendor_id?: string | null
  is_featured?: boolean | null
  vendor_profiles?: { id: string; business_name: string } | null
}

export default function ServicesPage() {
  const supabase = useStableSupabase()
  const { isOnline } = useNetworkStatus()
  const abortControllerRef = useRef<AbortController | null>(null)
  const [rows, setRows] = useState<ServiceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [err, setErr] = useState<string | null>(null)
  const [savingId, setSavingId] = useState<string | null>(null)

  // UI state
  const [search, setSearch] = useState('')
  const [groupByVendor, setGroupByVendor] = useState(true)
  const [sortBy, setSortBy] = useState<'vendor' | 'service' | 'price'>('vendor')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  
  // Filter state
  const [selectedCategories, setSelectedCategories] = useState<string[]>([])
  const [selectedTags, setSelectedTags] = useState<string[]>([])
  const [showFilters, setShowFilters] = useState(false)

  const load = useCallback(async () => {
    // Cancel previous request if still pending
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
    }

    const controller = new AbortController()
    abortControllerRef.current = controller

    if (!isOnline) {
      setErr('No internet connection. Please check your network.')
      setLoading(false)
      return
    }

    setLoading(true)
    setErr(null)
    
    try {
      // Try to load with all fields including tags
      const result = await safeQuery(
        async (sb) => {
          return await sb
            .from('services')
            .select('id, name, price, is_active, is_visible_to_users, category, category_id, tags, media_urls, vendor_id, is_featured, vendor_profiles(id,business_name)')
            .order('created_at', { ascending: false })
            .limit(500)
        },
        { signal: controller.signal, timeout: 30000, maxRetries: 3 }
      )

      // Check if request was cancelled
      if (controller.signal.aborted) {
        return
      }

      let { data, error } = result
      
      if (error) {
        // Fallback if tags column doesn't exist yet
        const fbResult = await safeQuery(
          async (sb) => {
            return await sb
              .from('services')
              .select('id, name, price, is_active, is_visible_to_users, category, category_id, media_urls, vendor_id, is_featured, vendor_profiles(id,business_name)')
              .order('created_at', { ascending: false })
              .limit(500)
          },
          { signal: controller.signal, timeout: 30000, maxRetries: 2 }
        )

        if (controller.signal.aborted) return

        if (fbResult.error) {
          // Final fallback without category_id, tags, is_featured
          const fb2Result = await safeQuery(
            async (sb) => {
              return await sb
                .from('services')
                .select('id, name, price, is_active, is_visible_to_users, category, media_urls, vendor_id, vendor_profiles(id,business_name)')
                .order('created_at', { ascending: false })
                .limit(500)
            },
            { signal: controller.signal, timeout: 30000, maxRetries: 2 }
          )

          if (controller.signal.aborted) return

          if (fb2Result.error) {
            setErr(`${error.message} | Fallback: ${fbResult.error.message} | Fallback2: ${fb2Result.error.message}`)
          } else {
            // Normalize fallback data to match ServiceRow type
            data = fb2Result.data?.map((row: any) => ({
              ...row,
              category_id: row.category_id || null,
              tags: row.tags || [],
              is_featured: row.is_featured || null,
              // Normalize vendor_profiles: if it's an array, take the first item, otherwise use as-is
              vendor_profiles: Array.isArray(row.vendor_profiles) 
                ? (row.vendor_profiles.length > 0 ? row.vendor_profiles[0] : null)
                : row.vendor_profiles || null
            })) || null
          }
        } else {
          // Normalize fallback data to match ServiceRow type
          data = fbResult.data?.map((row: any) => ({
            ...row,
            tags: row.tags || [],
            // Normalize vendor_profiles: if it's an array, take the first item, otherwise use as-is
            vendor_profiles: Array.isArray(row.vendor_profiles) 
              ? (row.vendor_profiles.length > 0 ? row.vendor_profiles[0] : null)
              : row.vendor_profiles || null
          })) || null
        }
      }
      
      // Ensure all required fields exist with defaults
      if (data) {
        data = data.map((row: any) => ({
          ...row,
          category_id: row.category_id ?? null,
          tags: row.tags || [],
          is_featured: row.is_featured ?? null,
          // Normalize vendor_profiles: if it's an array, take the first item, otherwise use as-is
          vendor_profiles: Array.isArray(row.vendor_profiles) 
            ? (row.vendor_profiles.length > 0 ? row.vendor_profiles[0] : null)
            : row.vendor_profiles || null
        }))
        setRows(data as ServiceRow[])
      }
    } catch (e: any) {
      if (!controller.signal.aborted) {
        setErr(e.message || 'Failed to load services')
      }
    } finally {
      if (!controller.signal.aborted) {
        setLoading(false)
      }
    }
  }, [isOnline])

  useEffect(() => {
    load()
    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort()
      }
    }
  }, [load])
  
  // Extract unique categories and tags from services (performance optimized)
  const availableCategories = useMemo(() => {
    const categories = new Set<string>()
    rows.forEach(row => {
      if (row.category) categories.add(row.category)
    })
    return Array.from(categories).sort()
  }, [rows])
  
  const availableTags = useMemo(() => {
    const tags = new Set<string>()
    rows.forEach(row => {
      if (row.tags && Array.isArray(row.tags)) {
        row.tags.forEach(tag => tags.add(tag))
      }
    })
    return Array.from(tags).sort()
  }, [rows])
  
  // Filtered rows based on search and filters (performance optimized)
  const filteredRows = useMemo(() => {
    let filtered = rows
    
    // Search filter
    const searchLower = search.trim().toLowerCase()
    if (searchLower) {
      filtered = filtered.filter(r =>
        (r.vendor_profiles?.business_name || '').toLowerCase().includes(searchLower) ||
        (r.name || '').toLowerCase().includes(searchLower)
      )
    }
    
    // Category filter (multi-select)
    if (selectedCategories.length > 0) {
      filtered = filtered.filter(r => 
        r.category && selectedCategories.includes(r.category)
      )
    }
    
    // Tags filter (multi-select)
    if (selectedTags.length > 0) {
      filtered = filtered.filter(r => {
        if (!r.tags || !Array.isArray(r.tags)) return false
        return selectedTags.some(tag => r.tags!.includes(tag))
      })
    }
    
    return filtered
  }, [rows, search, selectedCategories, selectedTags])
  
  const toggleCategory = useCallback((category: string) => {
    setSelectedCategories(prev => 
      prev.includes(category)
        ? prev.filter(c => c !== category)
        : [...prev, category]
    )
  }, [])
  
  const toggleTag = useCallback((tag: string) => {
    setSelectedTags(prev => 
      prev.includes(tag)
        ? prev.filter(t => t !== tag)
        : [...prev, tag]
    )
  }, [])
  
  const clearFilters = useCallback(() => {
    setSelectedCategories([])
    setSelectedTags([])
    setSearch('')
  }, [])

  const toggleFeatured = async (id: string, next: boolean) => {
    setSavingId(id)
    const { error } = await supabase.from('services').update({ is_featured: next }).eq('id', id)
    setSavingId(null)
    if (error) setErr(error.message)
    else setRows(prev => prev.map(r => r.id === id ? { ...r, is_featured: next } : r))
  }

  return (
    <main className="p-6">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">Services</h1>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={load} disabled={loading}>{loading ? 'Refreshing...' : 'Refresh'}</Button>
        </div>
      </div>
      {err && (
        <div className="mb-3 text-sm text-red-600">{err}</div>
      )}

      {/* Controls */}
      <div className="bg-white rounded-xl border p-4 md:p-5 mb-4 shadow-sm">
        <div className="grid grid-cols-1 md:grid-cols-12 gap-4 items-end">
          {/* Search */}
          <div className="md:col-span-5">
            <div className="relative">
              <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <SearchIcon className="h-4 w-4" />
              </span>
              <Input
                placeholder="Search by vendor or service name"
                value={search}
                onChange={(e) => { setSearch(e.target.value) }}
                className="pl-9 pr-9"
                aria-label="Search services"
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
                  aria-label="Clear search"
                >
                  <XIcon className="h-4 w-4" />
                </button>
              )}
            </div>
          </div>

          {/* Filter Toggle */}
          <div className="md:col-span-2">
            <Button
              variant="outline"
              onClick={() => setShowFilters(!showFilters)}
              className="w-full"
            >
              <Filter className="h-4 w-4 mr-2" />
              Filters
              {(selectedCategories.length > 0 || selectedTags.length > 0) && (
                <span className="ml-2 bg-blue-500 text-white text-xs rounded-full px-2 py-0.5">
                  {selectedCategories.length + selectedTags.length}
                </span>
              )}
            </Button>
          </div>

          {/* View mode */}
          <div className="md:col-span-2">
            <label className="block mb-1 text-xs font-medium text-gray-600">View</label>
            <select
              className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
              value={groupByVendor ? 'group' : 'list'}
              onChange={(e) => setGroupByVendor(e.target.value === 'group')}
              aria-label="View mode"
            >
              <option value="group">Group by Vendor</option>
              <option value="list">Flat List</option>
            </select>
          </div>

          {/* Sort */}
          <div className="md:col-span-3">
            <label className="block mb-1 text-xs font-medium text-gray-600">Sort</label>
            <div className="relative">
              <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <ArrowUpDown className="h-4 w-4" />
              </span>
              <select
                className="w-full h-10 rounded-md border border-input bg-background pl-9 pr-3 text-sm"
                value={`${sortBy}:${sortDir}`}
                onChange={(e) => {
                  const [k, d] = e.target.value.split(':') as [any, any]
                  setSortBy(k)
                  setSortDir(d)
                }}
                aria-label="Sort services"
              >
                <option value="vendor:asc">Vendor A-Z</option>
                <option value="vendor:desc">Vendor Z-A</option>
                <option value="service:asc">Service A-Z</option>
                <option value="service:desc">Service Z-A</option>
                <option value="price:asc">Price ↑</option>
                <option value="price:desc">Price ↓</option>
              </select>
            </div>
          </div>
        </div>
        
        {/* Filters Panel */}
        {showFilters && (
          <div className="mt-4 pt-4 border-t border-gray-200">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-semibold text-gray-700">Filters</h3>
              {(selectedCategories.length > 0 || selectedTags.length > 0) && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={clearFilters}
                  className="text-xs"
                >
                  Clear All
                </Button>
              )}
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Category Filter */}
              <div>
                <label className="block mb-2 text-xs font-medium text-gray-600">
                  Categories ({selectedCategories.length} selected)
                </label>
                <div className="max-h-48 overflow-y-auto border border-gray-200 rounded-md p-2 space-y-1">
                  {availableCategories.length === 0 ? (
                    <p className="text-xs text-gray-500 py-2">No categories available</p>
                  ) : (
                    availableCategories.map(category => (
                      <label
                        key={category}
                        className="flex items-center space-x-2 p-2 hover:bg-gray-50 rounded cursor-pointer"
                      >
                        <input
                          type="checkbox"
                          checked={selectedCategories.includes(category)}
                          onChange={() => toggleCategory(category)}
                          className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                        />
                        <span className="text-sm text-gray-700">{category}</span>
                      </label>
                    ))
                  )}
                </div>
              </div>
              
              {/* Tags Filter */}
              <div>
                <label className="block mb-2 text-xs font-medium text-gray-600">
                  Tags / Attributes ({selectedTags.length} selected)
                </label>
                <div className="max-h-48 overflow-y-auto border border-gray-200 rounded-md p-2 space-y-1">
                  {availableTags.length === 0 ? (
                    <p className="text-xs text-gray-500 py-2">No tags available</p>
                  ) : (
                    availableTags.map(tag => (
                      <label
                        key={tag}
                        className="flex items-center space-x-2 p-2 hover:bg-gray-50 rounded cursor-pointer"
                      >
                        <input
                          type="checkbox"
                          checked={selectedTags.includes(tag)}
                          onChange={() => toggleTag(tag)}
                          className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                        />
                        <span className="text-sm text-gray-700">{tag}</span>
                      </label>
                    ))
                  )}
                </div>
              </div>
            </div>
            
            {/* Active Filters Display */}
            {(selectedCategories.length > 0 || selectedTags.length > 0) && (
              <div className="mt-3 pt-3 border-t border-gray-200">
                <div className="flex flex-wrap gap-2">
                  {selectedCategories.map(category => (
                    <span
                      key={category}
                      className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full"
                    >
                      {category}
                      <button
                        onClick={() => toggleCategory(category)}
                        className="hover:bg-blue-200 rounded-full p-0.5"
                        aria-label={`Remove ${category} filter`}
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </span>
                  ))}
                  {selectedTags.map(tag => (
                    <span
                      key={tag}
                      className="inline-flex items-center gap-1 px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full"
                    >
                      {tag}
                      <button
                        onClick={() => toggleTag(tag)}
                        className="hover:bg-green-200 rounded-full p-0.5"
                        aria-label={`Remove ${tag} filter`}
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
      
      {/* Results Count */}
      <div className="mb-3 text-sm text-gray-600">
        Showing {filteredRows.length} of {rows.length} services
        {(selectedCategories.length > 0 || selectedTags.length > 0) && (
          <span className="text-blue-600"> (filtered)</span>
        )}
      </div>

      {groupByVendor ? (
        <VendorsGrouped
          rows={filteredRows}
          search={search}
          sortBy={sortBy}
          sortDir={sortDir}
          toggleFeatured={toggleFeatured}
          savingId={savingId}
        />
      ) : (
        <FlatList
          rows={filteredRows}
          search={search}
          sortBy={sortBy}
          sortDir={sortDir}
          toggleFeatured={toggleFeatured}
          savingId={savingId}
        />
      )}
    </main>
  )
}


function VendorsGrouped({
  rows,
  search,
  sortBy,
  sortDir,
  toggleFeatured,
  savingId,
}: {
  rows: ServiceRow[]
  search: string
  sortBy: 'vendor' | 'service' | 'price'
  sortDir: 'asc' | 'desc'
  toggleFeatured: (id: string, next: boolean) => Promise<void>
  savingId: string | null
}) {
  const filtered = useMemo(() => {
    let list = rows
    const q = search.trim().toLowerCase()
    if (q) {
      list = list.filter(r =>
        (r.vendor_profiles?.business_name || '').toLowerCase().includes(q) ||
        (r.name || '').toLowerCase().includes(q)
      )
    }
    return list
  }, [rows, search])

  const groups = useMemo(() => {
    const map = new Map<string, ServiceRow[]>()
    filtered.forEach(r => {
      const key = r.vendor_profiles?.business_name || r.vendor_id || 'Unknown Vendor'
      const arr = map.get(key) || []
      arr.push(r)
      map.set(key, arr)
    })
    const sortedVendors = Array.from(map.entries()).sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1
      return a[0].localeCompare(b[0]) * (sortBy === 'vendor' ? dir : 1)
    })
    return sortedVendors
  }, [filtered, sortBy, sortDir])

  // Collapse/expand state per vendor
  const [openVendors, setOpenVendors] = useState<Record<string, boolean>>({})
  useEffect(() => {
    // When vendor list changes, ensure keys exist; default to open
    setOpenVendors(prev => {
      const next: Record<string, boolean> = { ...prev }
      for (const [vendorName] of groups) {
        if (next[vendorName] == null) next[vendorName] = true
      }
      // Remove stale keys
      Object.keys(next).forEach(k => {
        if (!groups.find(([v]) => v === k)) delete next[k]
      })
      return next
    })
  }, [groups])

  const setAll = (open: boolean) => {
    const next: Record<string, boolean> = {}
    for (const [vendorName] of groups) next[vendorName] = open
    setOpenVendors(next)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-end gap-2">
        <Button variant="outline" onClick={() => setAll(true)}>Expand all</Button>
        <Button variant="outline" onClick={() => setAll(false)}>Collapse all</Button>
      </div>
      
      {groups.map(([vendorName, services]) => (
        <div key={vendorName} className="bg-white rounded-xl border">
          <button
            className="w-full text-left px-4 py-3 flex items-center justify-between hover:bg-gray-50 transition-colors"
            onClick={() => setOpenVendors(prev => ({ ...prev, [vendorName]: !prev[vendorName] }))}
          >
            <div className="flex items-center gap-3">
              <span className={`inline-flex h-5 w-5 items-center justify-center rounded-full border transition-transform duration-300 ${openVendors[vendorName] ? 'rotate-90' : 'rotate-0'}`}>
                <ChevronRight className="h-3.5 w-3.5" />
              </span>
              <div>
                <div className="text-base font-semibold">{vendorName}</div>
                <div className="text-xs text-gray-500">{services.length} service(s)</div>
              </div>
            </div>
            <div className="text-sm text-gray-500">{openVendors[vendorName] ? 'Hide' : 'Show'}</div>
          </button>
          <div className={`grid transition-all duration-300 ${openVendors[vendorName] ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'}`}>
            <div className="overflow-hidden">
              <div className="overflow-x-auto">
                <table className="min-w-full text-sm">
                  <thead className="bg-gray-50 text-left">
                    <tr>
                      <th className="p-3">Media</th>
                      <th className="p-3">Service</th>
                      <th className="p-3">Category</th>
                      <th className="p-3">Price</th>
                      <th className="p-3">Active</th>
                      <th className="p-3">Visible</th>
                      <th className="p-3">Featured</th>
                    </tr>
                  </thead>
                  <tbody>
                    {services
                      .slice()
                      .sort((a, b) => {
                        const dir = sortDir === 'asc' ? 1 : -1
                        if (sortBy === 'service') return a.name.localeCompare(b.name) * dir
                        if (sortBy === 'price') return (Number(a.price || 0) - Number(b.price || 0)) * dir
                        return 0
                      })
                      .map(s => (
                      <tr key={s.id} className="border-t">
                        <td className="p-3">
                          {s.media_urls && s.media_urls.length > 0 ? (
                            <Image src={s.media_urls[0]} alt={s.name} width={56} height={40} className="rounded object-cover" />
                          ) : (
                            <div className="w-14 h-10 bg-gray-100 rounded" />
                          )}
                        </td>
                        <td className="p-3 font-medium">{s.name}</td>
                        <td className="p-3">{s.category ?? '-'}</td>
                        <td className="p-3">{s.price != null ? `₹${Number(s.price).toFixed(0)}` : '-'}</td>
                        <td className="p-3">{s.is_active ? 'Yes' : 'No'}</td>
                        <td className="p-3">{s.is_visible_to_users ? 'Yes' : 'No'}</td>
                        <td className="p-3">
                          {typeof s.is_featured === 'boolean' ? (
                            <label className="inline-flex items-center gap-2">
                              <input type="checkbox" checked={!!s.is_featured} onChange={e=>toggleFeatured(s.id, e.target.checked)} disabled={savingId===s.id} />
                              {savingId===s.id && <span className="text-xs text-gray-500">Saving...</span>}
                            </label>
                          ) : (
                            <span className="text-xs text-gray-400">Add column is_featured to enable</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      ))}
      {groups.length === 0 && (
        <div className="text-sm text-gray-600">No services</div>
      )}
    </div>
  )
}

function FlatList({
  rows,
  search,
  sortBy,
  sortDir,
  toggleFeatured,
  savingId,
}: {
  rows: ServiceRow[]
  search: string
  sortBy: 'vendor' | 'service' | 'price'
  sortDir: 'asc' | 'desc'
  toggleFeatured: (id: string, next: boolean) => Promise<void>
  savingId: string | null
}) {
  const filtered = useMemo(() => {
    let list = rows
    const q = search.trim().toLowerCase()
    if (q) {
      list = list.filter(r =>
        (r.vendor_profiles?.business_name || '').toLowerCase().includes(q) ||
        (r.name || '').toLowerCase().includes(q)
      )
    }
    list = list.slice().sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1
      if (sortBy === 'vendor') return (a.vendor_profiles?.business_name || '').localeCompare(b.vendor_profiles?.business_name || '') * dir
      if (sortBy === 'service') return a.name.localeCompare(b.name) * dir
      if (sortBy === 'price') return (Number(a.price || 0) - Number(b.price || 0)) * dir
      return 0
    })
    return list
  }, [rows, search, sortBy, sortDir])

  return (
    <div className="bg-white rounded-xl border overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-gray-50 text-left">
          <tr>
            <th className="p-3">Media</th>
            <th className="p-3">Service</th>
            <th className="p-3">Vendor</th>
            <th className="p-3">Category</th>
            <th className="p-3">Price</th>
            <th className="p-3">Active</th>
            <th className="p-3">Visible</th>
            <th className="p-3">Featured</th>
          </tr>
        </thead>
        <tbody>
          {filtered.length === 0 ? (
            <tr><td className="p-3" colSpan={8}>No services</td></tr>
          ) : filtered.map(s => (
            <tr key={s.id} className="border-t">
              <td className="p-3">
                {s.media_urls && s.media_urls.length > 0 ? (
                  <Image src={s.media_urls[0]} alt={s.name} width={56} height={40} className="rounded object-cover" />
                ) : (
                  <div className="w-14 h-10 bg-gray-100 rounded" />
                )}
              </td>
              <td className="p-3 font-medium">{s.name}</td>
              <td className="p-3">{s.vendor_profiles?.business_name || s.vendor_id || '-'}</td>
              <td className="p-3">{s.category ?? '-'}</td>
              <td className="p-3">{s.price != null ? `₹${Number(s.price).toFixed(0)}` : '-'}</td>
              <td className="p-3">{s.is_active ? 'Yes' : 'No'}</td>
              <td className="p-3">{s.is_visible_to_users ? 'Yes' : 'No'}</td>
              <td className="p-3">
                {typeof s.is_featured === 'boolean' ? (
                  <label className="inline-flex items-center gap-2">
                    <input type="checkbox" checked={!!s.is_featured} onChange={e=>toggleFeatured(s.id, e.target.checked)} disabled={savingId===s.id} />
                    {savingId===s.id && <span className="text-xs text-gray-500">Saving...</span>}
                  </label>
                ) : (
                  <span className="text-xs text-gray-400">Add column is_featured to enable</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}


