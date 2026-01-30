"use client"

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase'
import {
  TicketPercent,
  Plus,
  Pencil,
  Trash2,
  Phone,
  ChevronDown,
  ChevronRight,
  X,
  UserPlus,
} from 'lucide-react'

// Normalize phone: digits only; accept 10 digits (India) or 10–15 with optional + prefix
function normalizePhone(input: string): string {
  return input.replace(/\D/g, '').trim()
}

function validatePhone(phone: string): { valid: boolean; error?: string } {
  const digits = normalizePhone(phone)
  if (digits.length === 0) return { valid: false, error: 'Phone number is required' }
  if (digits.length !== 10) return { valid: false, error: 'Phone must be exactly 10 digits' }
  if (!/^\d+$/.test(digits)) return { valid: false, error: 'Phone must contain only digits (with optional + at start)' }
  return { valid: true }
}

function parsePhoneLines(text: string): string[] {
  return text
    .split(/[\n,;]+/)
    .map((s) => normalizePhone(s))
    .filter((s) => s.length > 0)
}

interface Coupon {
  id: string
  code: string
  description: string | null
  discount_type: 'percentage' | 'fixed'
  discount_value: number
  min_order_value: number
  max_discount_amount: number | null
  valid_from: string
  valid_until: string | null
  usage_limit: number | null
  times_used: number
  first_order_only: boolean
  is_active: boolean
  conditions: Record<string, unknown> | null
  created_at: string
  updated_at: string
}

interface CouponPhoneWhitelist {
  id: string
  coupon_id: string
  phone_number: string
  notes: string | null
  created_at: string
}

const emptyCoupon = (): Partial<Coupon> => ({
  code: '',
  description: '',
  discount_type: 'percentage',
  discount_value: 0,
  min_order_value: 0,
  max_discount_amount: null,
  valid_from: new Date().toISOString().slice(0, 16),
  valid_until: null,
  usage_limit: null,
  times_used: 0,
  first_order_only: false,
  is_active: true,
  conditions: {},
})

export default function CouponsPage() {
  const [coupons, setCoupons] = useState<Coupon[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState<Partial<Coupon>>(emptyCoupon())
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [whitelists, setWhitelists] = useState<Record<string, CouponPhoneWhitelist[]>>({})
  const [newPhone, setNewPhone] = useState<Record<string, string>>({})
  const supabase = createClient()

  // First-order discount by phone section
  const [firstOrderMode, setFirstOrderMode] = useState<'new' | 'existing'>('new')
  const [firstOrderCouponId, setFirstOrderCouponId] = useState<string>('')
  const [firstOrderDiscountType, setFirstOrderDiscountType] = useState<'percentage' | 'fixed'>('percentage')
  const [firstOrderDiscountValue, setFirstOrderDiscountValue] = useState<string>('')
  const [firstOrderPhoneTags, setFirstOrderPhoneTags] = useState<string[]>([])
  const [firstOrderPhoneInput, setFirstOrderPhoneInput] = useState<string>('')
  const [firstOrderPhoneInputError, setFirstOrderPhoneInputError] = useState<string>('')
  const [firstOrderErrors, setFirstOrderErrors] = useState<{
    discount?: string
    phones?: string[]
    general?: string
  }>({})
  const [firstOrderSubmitting, setFirstOrderSubmitting] = useState(false)

  const loadCoupons = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('coupons')
        .select('*')
        .order('created_at', { ascending: false })
      if (error) throw error
      setCoupons(data || [])
    } catch (err) {
      console.error(err)
      setError('Failed to load coupons')
    } finally {
      setLoading(false)
    }
  }

  const loadWhitelist = async (couponId: string) => {
    const { data } = await supabase
      .from('coupon_phone_whitelist')
      .select('*')
      .eq('coupon_id', couponId)
      .order('created_at', { ascending: false })
    setWhitelists((prev) => ({ ...prev, [couponId]: data || [] }))
  }

  useEffect(() => {
    loadCoupons()
  }, [])

  useEffect(() => {
    if (expandedId) loadWhitelist(expandedId)
  }, [expandedId])

  const toggleExpand = (id: string) => {
    setExpandedId((prev) => (prev === id ? null : id))
  }

  const saveCoupon = async () => {
    try {
      setError(null)
      const payload = {
        code: form.code?.trim().toUpperCase() || '',
        description: form.description?.trim() || null,
        discount_type: form.discount_type,
        discount_value: Number(form.discount_value) || 0,
        min_order_value: Number(form.min_order_value) || 0,
        max_discount_amount: (form.max_discount_amount != null && String(form.max_discount_amount).trim() !== '') ? Number(form.max_discount_amount) : null,
        valid_from: form.valid_from ? new Date(form.valid_from).toISOString() : new Date().toISOString(),
        valid_until: form.valid_until ? new Date(form.valid_until).toISOString() : null,
        usage_limit: (form.usage_limit != null && String(form.usage_limit).trim() !== '') ? Number(form.usage_limit) : null,
        first_order_only: !!form.first_order_only,
        is_active: form.is_active !== false,
        conditions: form.conditions || {},
      }
      if (editingId) {
        const { error } = await supabase.from('coupons').update(payload).eq('id', editingId)
        if (error) throw error
        setSuccess('Coupon updated')
      } else {
        const { error } = await supabase.from('coupons').insert(payload)
        if (error) throw error
        setSuccess('Coupon created')
      }
      setEditingId(null)
      setCreating(false)
      setForm(emptyCoupon())
      await loadCoupons()
      setTimeout(() => setSuccess(null), 3000)
    } catch (err: any) {
      setError(err?.message || 'Failed to save coupon')
    }
  }

  const deleteCoupon = async (c: Coupon) => {
    if (!confirm(`Delete coupon "${c.code}"? This cannot be undone.`)) return
    try {
      const { error } = await supabase.from('coupons').delete().eq('id', c.id)
      if (error) throw error
      setSuccess('Coupon deleted')
      await loadCoupons()
      setEditingId(null)
      setExpandedId(null)
      setTimeout(() => setSuccess(null), 3000)
    } catch (err: any) {
      setError(err?.message || 'Failed to delete')
    }
  }

  const addPhoneToWhitelist = async (couponId: string) => {
    const phone = (newPhone[couponId] || '').trim().replace(/\D/g, '')
    if (!phone) return
    try {
      const { error } = await supabase.from('coupon_phone_whitelist').insert({
        coupon_id: couponId,
        phone_number: phone,
      })
      if (error) throw error
      setNewPhone((prev) => ({ ...prev, [couponId]: '' }))
      await loadWhitelist(couponId)
      setSuccess('Phone number added')
      setTimeout(() => setSuccess(null), 2000)
    } catch (err: any) {
      setError(err?.message || 'Failed to add phone')
    }
  }

  const removePhoneFromWhitelist = async (couponId: string, rowId: string) => {
    try {
      const { error } = await supabase.from('coupon_phone_whitelist').delete().eq('id', rowId)
      if (error) throw error
      await loadWhitelist(couponId)
      setSuccess('Phone removed')
      setTimeout(() => setSuccess(null), 2000)
    } catch (err: any) {
      setError(err?.message || 'Failed to remove')
    }
  }

  const startEdit = (c: Coupon) => {
    setForm({
      ...c,
      valid_from: c.valid_from ? c.valid_from.slice(0, 16) : '',
      valid_until: c.valid_until ? c.valid_until.slice(0, 16) : null,
    })
    setEditingId(c.id)
    setCreating(false)
  }

  const startCreate = () => {
    setForm(emptyCoupon())
    setCreating(true)
    setEditingId(null)
  }

  const cancelForm = () => {
    setCreating(false)
    setEditingId(null)
    setForm(emptyCoupon())
  }

  const firstOrderOnlyCoupons = coupons.filter((c) => c.first_order_only && c.is_active)

  const addFirstOrderPhoneTag = () => {
    const raw = firstOrderPhoneInput.trim()
    if (!raw) {
      setFirstOrderPhoneInputError('Enter a phone number')
      return
    }
    const result = validatePhone(raw)
    if (!result.valid) {
      setFirstOrderPhoneInputError(result.error || 'Invalid phone')
      return
    }
    const digits = normalizePhone(raw)
    if (firstOrderPhoneTags.includes(digits)) {
      setFirstOrderPhoneInputError('Already added')
      return
    }
    setFirstOrderPhoneTags((prev) => [...prev, digits])
    setFirstOrderPhoneInput('')
    setFirstOrderPhoneInputError('')
  }

  const removeFirstOrderPhoneTag = (phone: string) => {
    setFirstOrderPhoneTags((prev) => prev.filter((p) => p !== phone))
  }

  const submitFirstOrderByPhone = async () => {
    setFirstOrderErrors({})
    const err: { discount?: string; phones?: string[]; general?: string } = {}

    const discountNum = Number(firstOrderDiscountValue)
    if (firstOrderMode === 'new') {
      if (firstOrderDiscountValue.trim() === '' || isNaN(discountNum)) {
        err.discount = 'Discount value is required'
      } else if (firstOrderDiscountType === 'percentage') {
        if (discountNum < 1 || discountNum > 100) err.discount = 'Percentage must be between 1 and 100'
      } else {
        if (discountNum < 1 || discountNum > 100000) err.discount = 'Fixed discount must be between ₹1 and ₹1,00,000'
      }
    }

    if (firstOrderMode === 'existing' && !firstOrderCouponId) {
      err.general = 'Please select a coupon'
    }

    const validPhones = [...firstOrderPhoneTags]
    if (validPhones.length === 0) {
      err.phones = ['Add at least one phone number using the field above']
    }

    if (Object.keys(err).length > 0) {
      setFirstOrderErrors(err)
      return
    }

    setFirstOrderSubmitting(true)
    try {
      let couponId = firstOrderCouponId
      if (firstOrderMode === 'new') {
        const code = `FIRST_${Date.now().toString(36).toUpperCase()}`
        const payload = {
          code,
          description: `First order discount: ${firstOrderDiscountType === 'percentage' ? `${discountNum}%` : `₹${discountNum}`} off`,
          discount_type: firstOrderDiscountType,
          discount_value: discountNum,
          min_order_value: 0,
          max_discount_amount: null,
          valid_from: new Date().toISOString(),
          valid_until: null,
          usage_limit: null,
          first_order_only: true,
          is_active: true,
          conditions: {},
        }
        const { data: inserted, error } = await supabase.from('coupons').insert(payload).select('id').single()
        if (error) throw error
        couponId = inserted.id
      }

      for (const phone of validPhones) {
        const { error } = await supabase.from('coupon_phone_whitelist').insert({
          coupon_id: couponId,
          phone_number: phone,
        })
        if (error) {
          if (error.code === '23505') continue
          throw error
        }
      }
      setSuccess(`Added ${validPhones.length} user(s) for first-order discount.`)
      setFirstOrderPhoneTags([])
      setFirstOrderPhoneInput('')
      setFirstOrderPhoneInputError('')
      if (firstOrderMode === 'new') setFirstOrderDiscountValue('')
      await loadCoupons()
      if (couponId) await loadWhitelist(couponId)
      setTimeout(() => setSuccess(null), 4000)
    } catch (e: any) {
      setFirstOrderErrors({ general: e?.message || 'Failed to save' })
    } finally {
      setFirstOrderSubmitting(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <TicketPercent className="h-7 w-7 text-blue-600" />
            Coupon Management
          </h1>
          <p className="text-gray-600">
            Create and manage coupons for user orders. Add phone numbers for first-order-only discounts.
          </p>
        </div>
        <button
          onClick={startCreate}
          className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Plus className="h-5 w-5" />
          New Coupon
        </button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg flex items-center justify-between">
          <p className="text-red-600">{error}</p>
          <button onClick={() => setError(null)} className="text-red-500 hover:text-red-700 text-sm">
            Dismiss
          </button>
        </div>
      )}
      {success && (
        <div className="p-4 bg-green-50 border border-green-200 rounded-lg flex items-center justify-between">
          <p className="text-green-600">{success}</p>
          <button onClick={() => setSuccess(null)} className="text-green-500 hover:text-green-700 text-sm">
            Dismiss
          </button>
        </div>
      )}

      {/* First order discount — Add users by phone */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-gray-900 flex items-center gap-2 mb-1">
          <UserPlus className="h-5 w-5 text-blue-600" />
          First order discount — Add users by phone
        </h3>
        <p className="text-sm text-gray-500 mb-4">
          Add phone numbers to apply a custom discount on the user&apos;s first order. Create a new offer or add to an existing first-order-only coupon.
        </p>

        <div className="space-y-4">
          <div className="flex flex-wrap gap-4">
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="firstOrderMode"
                checked={firstOrderMode === 'new'}
                onChange={() => setFirstOrderMode('new')}
                className="rounded border-gray-300"
              />
              <span className="text-sm font-medium text-gray-700">Create new offer</span>
            </label>
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="firstOrderMode"
                checked={firstOrderMode === 'existing'}
                onChange={() => setFirstOrderMode('existing')}
                className="rounded border-gray-300"
              />
              <span className="text-sm font-medium text-gray-700">Add to existing coupon</span>
            </label>
          </div>

          {firstOrderMode === 'new' && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Discount type *</label>
                <select
                  value={firstOrderDiscountType}
                  onChange={(e) => setFirstOrderDiscountType(e.target.value as 'percentage' | 'fixed')}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2"
                >
                  <option value="percentage">Percentage</option>
                  <option value="fixed">Fixed amount (₹)</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {firstOrderDiscountType === 'percentage' ? 'Discount % *' : 'Discount amount (₹) *'}
                </label>
                <input
                  type="number"
                  min={firstOrderDiscountType === 'percentage' ? 1 : 1}
                  max={firstOrderDiscountType === 'percentage' ? 100 : 100000}
                  step={firstOrderDiscountType === 'percentage' ? 1 : 10}
                  value={firstOrderDiscountValue}
                  onChange={(e) => setFirstOrderDiscountValue(e.target.value)}
                  placeholder={firstOrderDiscountType === 'percentage' ? 'e.g. 20' : 'e.g. 500'}
                  className={`w-full border rounded-lg px-3 py-2 ${
                    firstOrderErrors.discount ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {firstOrderErrors.discount && (
                  <p className="text-xs text-red-600 mt-1">{firstOrderErrors.discount}</p>
                )}
              </div>
            </div>
          )}

          {firstOrderMode === 'existing' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Select coupon *</label>
              <select
                value={firstOrderCouponId}
                onChange={(e) => setFirstOrderCouponId(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              >
                <option value="">— Select first-order coupon —</option>
                {firstOrderOnlyCoupons.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.code} — {c.discount_type === 'percentage' ? `${c.discount_value}%` : `₹${c.discount_value}`} off
                  </option>
                ))}
              </select>
              {firstOrderOnlyCoupons.length === 0 && (
                <p className="text-xs text-amber-600 mt-1">No active first-order-only coupons. Create one in the form above and check &quot;First order only&quot;.</p>
              )}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Phone numbers *</label>
            <div className="flex gap-2 flex-wrap">
              <input
                type="tel"
                value={firstOrderPhoneInput}
                onChange={(e) => {
                  setFirstOrderPhoneInput(e.target.value)
                  setFirstOrderPhoneInputError('')
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    addFirstOrderPhoneTag()
                  }
                }}
                placeholder="e.g. 9876543210 or +919876543210"
                className={`flex-1 min-w-[180px] border rounded-lg px-3 py-2 font-mono text-sm ${
                  firstOrderPhoneInputError || firstOrderErrors.phones?.length ? 'border-red-500' : 'border-gray-300'
                }`}
              />
              <button
                type="button"
                onClick={addFirstOrderPhoneTag}
                className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 border border-gray-300 font-medium text-sm"
              >
                Add
              </button>
            </div>
            {firstOrderPhoneInputError && (
              <p className="text-xs text-red-600 mt-1">{firstOrderPhoneInputError}</p>
            )}
            {firstOrderErrors.phones && firstOrderErrors.phones.length > 0 && (
              <p className="text-xs text-red-600 mt-1">{firstOrderErrors.phones[0]}</p>
            )}
            <p className="text-xs text-gray-500 mt-1">Exactly 10 digits (Indian mobile). Press Enter or click Add. Duplicates are not added.</p>

            {firstOrderPhoneTags.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {firstOrderPhoneTags.map((phone) => (
                  <span
                    key={phone}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-blue-50 text-blue-800 border border-blue-200 text-sm font-mono"
                  >
                    {phone}
                    <button
                      type="button"
                      onClick={() => removeFirstOrderPhoneTag(phone)}
                      className="p-0.5 rounded-full hover:bg-blue-200 text-blue-600 hover:text-blue-800"
                      aria-label={`Remove ${phone}`}
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {firstOrderErrors.general && (
            <p className="text-sm text-red-600">{firstOrderErrors.general}</p>
          )}

          <button
            type="button"
            onClick={submitFirstOrderByPhone}
            disabled={firstOrderSubmitting}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2"
          >
            {firstOrderSubmitting ? (
              <>
                <span className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent" />
                Saving…
              </>
            ) : (
              <>
                <UserPlus className="h-4 w-4" />
                Add users for first-order discount
              </>
            )}
          </button>
        </div>
      </div>

      {/* Create / Edit form */}
      {(creating || editingId) && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-lg font-semibold mb-4">{editingId ? 'Edit Coupon' : 'New Coupon'}</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Code *</label>
              <input
                type="text"
                value={form.code || ''}
                onChange={(e) => setForm((f) => ({ ...f, code: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 uppercase"
                placeholder="SAVE20"
                disabled={!!editingId}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <input
                type="text"
                value={form.description || ''}
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
                placeholder="20% off first order"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Discount type</label>
              <select
                value={form.discount_type || 'percentage'}
                onChange={(e) => setForm((f) => ({ ...f, discount_type: e.target.value as 'percentage' | 'fixed' }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              >
                <option value="percentage">Percentage</option>
                <option value="fixed">Fixed amount (₹)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {form.discount_type === 'percentage' ? 'Discount %' : 'Discount amount (₹)'}
              </label>
              <input
                type="number"
                min={0}
                step={form.discount_type === 'percentage' ? 1 : 10}
                value={form.discount_value ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, discount_value: e.target.value as unknown as number }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Min order value (₹)</label>
              <input
                type="number"
                min={0}
                value={form.min_order_value ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, min_order_value: e.target.value as unknown as number }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              />
            </div>
            {form.discount_type === 'percentage' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Max discount cap (₹)</label>
                <input
                  type="number"
                  min={0}
                  value={form.max_discount_amount ?? ''}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      max_discount_amount: e.target.value === '' ? null : (e.target.value as unknown as number),
                    }))
                  }
                  className="w-full border border-gray-300 rounded-lg px-3 py-2"
                  placeholder="Optional"
                />
              </div>
            )}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Valid from</label>
              <input
                type="datetime-local"
                value={form.valid_from || ''}
                onChange={(e) => setForm((f) => ({ ...f, valid_from: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Valid until (optional)</label>
              <input
                type="datetime-local"
                value={form.valid_until || ''}
                onChange={(e) => setForm((f) => ({ ...f, valid_until: e.target.value || null }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Usage limit (optional)</label>
              <input
                type="number"
                min={0}
                value={form.usage_limit ?? ''}
                onChange={(e) =>
                  setForm((f) => ({
                    ...f,
                    usage_limit: e.target.value === '' ? null : (e.target.value as unknown as number),
                  }))
                }
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
                placeholder="Unlimited"
              />
            </div>
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={!!form.first_order_only}
                  onChange={(e) => setForm((f) => ({ ...f, first_order_only: e.target.checked }))}
                  className="rounded border-gray-300"
                />
                <span className="text-sm text-gray-700">First order only</span>
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={form.is_active !== false}
                  onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                  className="rounded border-gray-300"
                />
                <span className="text-sm text-gray-700">Active</span>
              </label>
            </div>
          </div>
          <div className="mt-4 flex gap-2">
            <button
              onClick={saveCoupon}
              disabled={!form.code?.trim()}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
            >
              {editingId ? 'Update' : 'Create'}
            </button>
            <button onClick={cancelForm} className="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Coupons list */}
      <div className="bg-white rounded-lg border border-gray-200">
        <div className="p-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold">All Coupons</h3>
        </div>
        {loading ? (
          <div className="flex justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
          </div>
        ) : coupons.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            No coupons yet. Create one to get started.
          </div>
        ) : (
          <div className="divide-y divide-gray-200">
            {coupons.map((c) => (
              <div key={c.id}>
                <div
                  className="flex items-center justify-between p-4 hover:bg-gray-50 cursor-pointer"
                  onClick={() => toggleExpand(c.id)}
                >
                  <div className="flex items-center gap-3">
                    {expandedId === c.id ? (
                      <ChevronDown className="h-5 w-5 text-gray-500" />
                    ) : (
                      <ChevronRight className="h-5 w-5 text-gray-500" />
                    )}
                    <span className="font-mono font-semibold">{c.code}</span>
                    <span
                      className={`px-2 py-0.5 rounded text-xs ${
                        c.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-200 text-gray-600'
                      }`}
                    >
                      {c.is_active ? 'Active' : 'Inactive'}
                    </span>
                    {c.first_order_only && (
                      <span className="px-2 py-0.5 rounded text-xs bg-amber-100 text-amber-800">First order only</span>
                    )}
                    <span className="text-sm text-gray-500">
                      {c.discount_type === 'percentage' ? `${c.discount_value}%` : `₹${c.discount_value}`} off
                      {c.min_order_value > 0 && ` · Min ₹${c.min_order_value}`}
                    </span>
                    <span className="text-sm text-gray-400">
                      Used {c.times_used}
                      {c.usage_limit != null ? ` / ${c.usage_limit}` : ''}
                    </span>
                  </div>
                  <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
                    <button
                      onClick={() => startEdit(c)}
                      className="p-2 text-gray-500 hover:bg-gray-200 rounded-lg"
                      title="Edit"
                    >
                      <Pencil className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => deleteCoupon(c)}
                      className="p-2 text-red-500 hover:bg-red-50 rounded-lg"
                      title="Delete"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
                {expandedId === c.id && (
                  <div className="px-4 pb-4 pt-0 bg-gray-50 border-t border-gray-100">
                    <div className="flex items-center gap-2 mt-3 mb-2">
                      <Phone className="h-4 w-4 text-gray-600" />
                      <span className="text-sm font-medium text-gray-700">First-order discount: add phone numbers</span>
                    </div>
                    <p className="text-xs text-gray-500 mb-2">
                      These numbers will get this coupon&apos;s discount on their first order (when &quot;First order
                      only&quot; is enabled).
                    </p>
                    <div className="flex gap-2 mb-3">
                      <input
                        type="tel"
                        value={newPhone[c.id] || ''}
                        onChange={(e) => setNewPhone((prev) => ({ ...prev, [c.id]: e.target.value }))}
                        placeholder="e.g. 9876543210"
                        className="border border-gray-300 rounded-lg px-3 py-2 text-sm w-48"
                        onKeyDown={(e) => e.key === 'Enter' && addPhoneToWhitelist(c.id)}
                      />
                      <button
                        onClick={() => addPhoneToWhitelist(c.id)}
                        className="px-3 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700"
                      >
                        Add
                      </button>
                    </div>
                    <ul className="space-y-1">
                      {(whitelists[c.id] || []).map((w) => (
                        <li key={w.id} className="flex items-center justify-between text-sm bg-white px-3 py-2 rounded">
                          <span>{w.phone_number}</span>
                          <button
                            onClick={() => removePhoneFromWhitelist(c.id, w.id)}
                            className="text-red-500 hover:text-red-700"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        </li>
                      ))}
                      {(whitelists[c.id] || []).length === 0 && (
                        <li className="text-sm text-gray-400 italic">No phone numbers added yet.</li>
                      )}
                    </ul>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
