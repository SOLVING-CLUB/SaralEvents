"use client"
import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase'
import Image from 'next/image'
import { Megaphone, Image as ImageIcon, PlusCircle, Eye, EyeOff, Trash2 } from 'lucide-react'

interface Banner {
  id: string
  asset_name: string
  asset_path: string
  bucket_name: string
  description: string
  is_active: boolean
  created_at: string
  file_size?: number
  mime_type?: string
}

export default function MarketingPage() {
  const [banners, setBanners] = useState<Banner[]>([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const supabase = createClient()

  useEffect(() => {
    loadBanners()
  }, [])

  const loadBanners = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('app_assets')
        .select('*')
        .eq('app_type', 'user')
        .eq('asset_type', 'banner')
        .order('created_at', { ascending: false })

      if (error) throw error
      setBanners(data || [])
    } catch (err) {
      console.error('Error loading banners:', err)
      setError('Failed to load banners')
    } finally {
      setLoading(false)
    }
  }

  const uploadBanner = async (file: File) => {
    try {
      setUploading(true)
      setError(null)

      if (!file.type.startsWith('image/')) {
        throw new Error('Please select an image file')
      }

      if (file.size > 5 * 1024 * 1024) {
        throw new Error('File size must be less than 5MB')
      }

      const fileExt = file.name.split('.').pop()
      const fileName = `banner_${Date.now()}.${fileExt}`
      const filePath = `banners/${fileName}`

      const { error: uploadError } = await supabase.storage
        .from('user-app-assets')
        .upload(filePath, file)

      if (uploadError) throw uploadError

      const { error: dbError } = await supabase
        .from('app_assets')
        .insert({
          app_type: 'user',
          asset_type: 'banner',
          asset_name: fileName.replace(/\.[^/.]+$/, ""),
          asset_path: filePath,
          bucket_name: 'user-app-assets',
          file_size: file.size,
          mime_type: file.type,
          description: `Banner uploaded on ${new Date().toLocaleDateString()}`,
          is_active: true
        })

      if (dbError) throw dbError

      await loadBanners()
      setSuccess('Banner uploaded successfully! Changes will appear in the user app within seconds.')
      setTimeout(() => setSuccess(null), 5000)
    } catch (err) {
      console.error('Error uploading banner:', err)
      setError(err instanceof Error ? err.message : 'Failed to upload banner')
    } finally {
      setUploading(false)
    }
  }

  const toggleBannerStatus = async (bannerId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('app_assets')
        .update({ is_active: !currentStatus })
        .eq('id', bannerId)

      if (error) throw error
      await loadBanners()
      setSuccess(`Banner ${!currentStatus ? 'activated' : 'deactivated'} successfully!`)
      setTimeout(() => setSuccess(null), 3000)
    } catch (err) {
      console.error('Error updating banner status:', err)
      setError('Failed to update banner status')
    }
  }

  const deleteBanner = async (banner: Banner) => {
    if (!confirm('Are you sure you want to delete this banner?')) return

    try {
      const { error: storageError } = await supabase.storage
        .from(banner.bucket_name)
        .remove([banner.asset_path])

      if (storageError) console.warn('Storage deletion error:', storageError)

      const { error: dbError } = await supabase
        .from('app_assets')
        .delete()
        .eq('id', banner.id)

      if (dbError) throw dbError
      await loadBanners()
      setSuccess('Banner deleted successfully')
      setTimeout(() => setSuccess(null), 3000)
    } catch (err) {
      console.error('Error deleting banner:', err)
      setError('Failed to delete banner')
    }
  }

  const getBannerUrl = (banner: Banner) => {
    return supabase.storage
      .from(banner.bucket_name)
      .getPublicUrl(banner.asset_path).data.publicUrl
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Megaphone className="h-7 w-7 text-blue-600" />
            Marketing & Promotions
          </h1>
          <p className="text-gray-600">
            Manage promotional banners and campaigns for the user app
          </p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-blue-50 rounded-full">
              <ImageIcon className="h-6 w-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Banners</p>
              <p className="text-2xl font-bold text-gray-900">{banners.length}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-green-50 rounded-full">
              <Eye className="h-6 w-6 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Active Banners</p>
              <p className="text-2xl font-bold text-green-600">{banners.filter(b => b.is_active).length}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-gray-100 rounded-full">
              <EyeOff className="h-6 w-6 text-gray-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Inactive Banners</p>
              <p className="text-2xl font-bold text-gray-600">{banners.filter(b => !b.is_active).length}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Upload Section */}
      <div className="bg-white p-6 rounded-lg border border-gray-200">
        <h3 className="text-lg font-semibold mb-4">Upload New Banner</h3>
        <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-blue-400 transition-colors">
          <label className="cursor-pointer">
            <div className="flex flex-col items-center">
              <PlusCircle className="h-12 w-12 text-gray-400 mb-3" />
              <p className="text-gray-600 mb-1">
                {uploading ? 'Uploading...' : 'Click to upload a banner image'}
              </p>
              <p className="text-sm text-gray-400">PNG, JPG, GIF up to 5MB</p>
            </div>
            <input
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) uploadBanner(file)
              }}
              disabled={uploading}
            />
          </label>
        </div>
        {banners.length > 1 && (
          <p className="text-sm text-blue-600 mt-3">
            📱 Multiple banners will display as a carousel in the user app
          </p>
        )}
      </div>

      {/* Messages */}
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

      {/* Banners Grid */}
      <div className="bg-white rounded-lg border border-gray-200">
        <div className="p-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold">All Banners</h3>
        </div>
        
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        ) : banners.length === 0 ? (
          <div className="text-center py-12">
            <ImageIcon className="mx-auto h-12 w-12 text-gray-300 mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-1">No banners uploaded</h3>
            <p className="text-gray-600">Upload your first promotional banner to get started</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 p-6">
            {banners.map((banner) => (
              <div key={banner.id} className="bg-gray-50 rounded-lg overflow-hidden border border-gray-200">
                <div className="aspect-video relative">
                  <Image
                    src={getBannerUrl(banner)}
                    alt={banner.asset_name}
                    fill
                    className="object-cover"
                  />
                  <div className={`absolute top-2 right-2 px-2 py-1 rounded text-xs font-medium ${
                    banner.is_active 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-gray-200 text-gray-600'
                  }`}>
                    {banner.is_active ? 'Active' : 'Inactive'}
                  </div>
                </div>
                
                <div className="p-4">
                  <h4 className="font-medium text-gray-900 mb-1 truncate">{banner.asset_name}</h4>
                  <p className="text-sm text-gray-500 mb-3">
                    {banner.file_size ? `${(banner.file_size / 1024).toFixed(1)} KB` : ''} • 
                    {new Date(banner.created_at).toLocaleDateString()}
                  </p>
                  
                  <div className="flex gap-2">
                    <button
                      onClick={() => toggleBannerStatus(banner.id, banner.is_active)}
                      className={`flex-1 px-3 py-2 text-sm rounded-lg flex items-center justify-center gap-1 transition ${
                        banner.is_active
                          ? 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                          : 'bg-green-100 text-green-700 hover:bg-green-200'
                      }`}
                    >
                      {banner.is_active ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                      {banner.is_active ? 'Hide' : 'Show'}
                    </button>
                    
                    <button
                      onClick={() => deleteBanner(banner)}
                      className="px-3 py-2 text-sm bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition flex items-center gap-1"
                    >
                      <Trash2 className="h-4 w-4" />
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

