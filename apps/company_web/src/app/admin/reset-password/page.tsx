"use client"
import { useState } from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase'

export default function ResetPasswordPage() {
  const supabase = createClient()
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (password !== confirm) return setError('Passwords do not match')
    setLoading(true)
    setError(null)
    setMessage(null)
    const { error } = await supabase.auth.updateUser({ password })
    setLoading(false)
    if (error) setError(error.message)
    else setMessage('Password updated. You can now sign in.')
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-6">
      <form onSubmit={onSubmit} className="max-w-sm w-full bg-white rounded-xl p-6 shadow">
        <h1 className="text-xl font-bold mb-4">Reset password</h1>
        <div className="space-y-3">
          <input value={password} onChange={e=>setPassword(e.target.value)} type="password" placeholder="New password" required className="w-full border rounded-md p-2" />
          <input value={confirm} onChange={e=>setConfirm(e.target.value)} type="password" placeholder="Confirm password" required className="w-full border rounded-md p-2" />
          {error && <p className="text-red-600 text-sm">{error}</p>}
          {message && <p className="text-green-700 text-sm">{message}</p>}
          <button disabled={loading} className="w-full bg-black text-white rounded-md py-2">{loading ? 'Updating...' : 'Update password'}</button>
        </div>
        <div className="mt-4 text-sm text-gray-600">
          <Link href="/admin/signin" className="hover:underline">Back to sign in</Link>
        </div>
      </form>
    </main>
  )
}


