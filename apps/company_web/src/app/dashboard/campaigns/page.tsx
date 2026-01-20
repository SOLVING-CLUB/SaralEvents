"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { 
  Bell, 
  Send, 
  Calendar, 
  Users, 
  Store, 
  UserCheck,
  Plus,
  X,
  Clock,
  CheckCircle,
  XCircle,
  AlertCircle,
  Image as ImageIcon,
  ExternalLink,
  Search,
  Filter
} from 'lucide-react'

interface Campaign {
  id: string
  title: string
  message: string
  cta_text: string | null
  cta_url: string | null
  cta_action: string | null
  target_audience: 'all_users' | 'all_vendors' | 'specific_users'
  target_user_ids: string[]
  image_url: string | null
  scheduled_at: string | null
  sent_at: string | null
  status: 'draft' | 'scheduled' | 'sending' | 'sent' | 'failed' | 'cancelled'
  sent_count: number
  failed_count: number
  total_recipients: number
  created_at: string
  updated_at: string
}

interface User {
  user_id: string
  first_name: string | null
  last_name: string | null
  email: string
}

interface Vendor {
  id: string
  business_name: string
  user_id: string
}

export default function CampaignsPage() {
  const supabase = createClient()
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [sending, setSending] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  
  // Form state
  const [formData, setFormData] = useState({
    title: '',
    message: '',
    cta_text: '',
    cta_url: '',
    cta_action: 'open_url',
    target_audience: 'all_users' as 'all_users' | 'all_vendors' | 'specific_users',
    target_user_ids: [] as string[],
    image_url: '',
    scheduled_at: '',
    send_immediately: true,
  })

  // User selection for specific_users
  const [users, setUsers] = useState<User[]>([])
  const [vendors, setVendors] = useState<Vendor[]>([])
  const [loadingUsers, setLoadingUsers] = useState(false)
  const [userSearchQuery, setUserSearchQuery] = useState('')
  const [showUserSelector, setShowUserSelector] = useState(false)

  useEffect(() => {
    loadCampaigns()
  }, [])

  async function loadCampaigns() {
    setLoading(true)
    try {
      const { data, error } = await supabase
        .from('notification_campaigns')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100)

      if (error) throw error
      setCampaigns(data || [])
    } catch (err: any) {
      console.error('Error loading campaigns:', err)
    } finally {
      setLoading(false)
    }
  }

  async function loadUsers() {
    if (users.length > 0) return // Already loaded
    
    setLoadingUsers(true)
    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('user_id, first_name, last_name, email')
        .limit(500)

      if (error) throw error
      setUsers(data || [])
    } catch (err: any) {
      console.error('Error loading users:', err)
    } finally {
      setLoadingUsers(false)
    }
  }

  async function loadVendors() {
    if (vendors.length > 0) return // Already loaded
    
    setLoadingUsers(true)
    try {
      const { data, error } = await supabase
        .from('vendor_profiles')
        .select('id, business_name, user_id')
        .limit(500)

      if (error) throw error
      setVendors(data || [])
    } catch (err: any) {
      console.error('Error loading vendors:', err)
    } finally {
      setLoadingUsers(false)
    }
  }

  async function sendCampaign() {
    if (!formData.title.trim() || !formData.message.trim()) {
      alert('Please fill in title and message')
      return
    }

    setSending(true)
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      // Prepare campaign data
      const campaignData: any = {
        title: formData.title.trim(),
        message: formData.message.trim(),
        target_audience: formData.target_audience,
        status: formData.send_immediately ? 'sending' : 'scheduled',
        created_by: user?.id,
      }

      if (formData.cta_text) {
        campaignData.cta_text = formData.cta_text.trim()
        campaignData.cta_url = formData.cta_url.trim() || null
        campaignData.cta_action = formData.cta_action
      }

      if (formData.image_url) {
        campaignData.image_url = formData.image_url.trim()
      }

      if (formData.target_audience === 'specific_users') {
        campaignData.target_user_ids = formData.target_user_ids
      }

      if (!formData.send_immediately && formData.scheduled_at) {
        campaignData.scheduled_at = formData.scheduled_at
      }

      // Create campaign record
      const { data: campaign, error: campaignError } = await supabase
        .from('notification_campaigns')
        .insert(campaignData)
        .select()
        .single()

      if (campaignError) throw campaignError

      // If sending immediately, send notifications
      if (formData.send_immediately) {
        await sendNotifications(campaign)
      }

      // Reset form and close modal
      resetForm()
      setShowCreateModal(false)
      await loadCampaigns()
      
      alert(formData.send_immediately 
        ? 'Campaign sent successfully!' 
        : 'Campaign scheduled successfully!')
    } catch (err: any) {
      console.error('Error sending campaign:', err)
      alert(`Error: ${err.message}`)
    } finally {
      setSending(false)
    }
  }

  async function sendNotifications(campaign: Campaign) {
    try {
      // Get target user IDs based on audience
      let targetUserIds: string[] = []

      if (campaign.target_audience === 'all_users') {
        const { data } = await supabase
          .from('user_profiles')
          .select('user_id')
        targetUserIds = (data || []).map(u => u.user_id)
      } else if (campaign.target_audience === 'all_vendors') {
        const { data } = await supabase
          .from('vendor_profiles')
          .select('user_id')
        targetUserIds = (data || []).map(v => v.user_id).filter(Boolean)
      } else if (campaign.target_audience === 'specific_users') {
        targetUserIds = campaign.target_user_ids || []
      }

      // Prepare notification data
      const notificationData: any = {
        type: 'campaign',
        campaign_id: campaign.id,
      }

      if (campaign.cta_url) {
        notificationData.cta_url = campaign.cta_url
        notificationData.cta_action = campaign.cta_action || 'open_url'
      }

      // Send notifications via edge function
      const results = await Promise.allSettled(
        targetUserIds.map(async userId => {
          const { data, error } = await supabase.functions.invoke('send-push-notification', {
            body: {
              userId,
              title: campaign.title,
              body: campaign.message,
              data: notificationData,
              imageUrl: campaign.image_url || undefined,
            },
          })
          if (error) throw error
          return data
        })
      )

      const successful = results.filter(r => r.status === 'fulfilled').length
      const failed = results.filter(r => r.status === 'rejected').length

      // Update campaign status
      await supabase
        .from('notification_campaigns')
        .update({
          status: 'sent',
          sent_at: new Date().toISOString(),
          sent_count: successful,
          failed_count: failed,
          total_recipients: targetUserIds.length,
        })
        .eq('id', campaign.id)
    } catch (err: any) {
      console.error('Error sending notifications:', err)
      await supabase
        .from('notification_campaigns')
        .update({ status: 'failed' })
        .eq('id', campaign.id)
      throw err
    }
  }

  function resetForm() {
    setFormData({
      title: '',
      message: '',
      cta_text: '',
      cta_url: '',
      cta_action: 'open_url',
      target_audience: 'all_users',
      target_user_ids: [],
      image_url: '',
      scheduled_at: '',
      send_immediately: true,
    })
    setUserSearchQuery('')
  }

  function toggleUserSelection(userId: string) {
    setFormData(prev => ({
      ...prev,
      target_user_ids: prev.target_user_ids.includes(userId)
        ? prev.target_user_ids.filter(id => id !== userId)
        : [...prev.target_user_ids, userId],
    }))
  }

  const filteredCampaigns = campaigns.filter(campaign => {
    if (statusFilter !== 'all' && campaign.status !== statusFilter) return false
    if (searchQuery) {
      const q = searchQuery.toLowerCase()
      return (
        campaign.title.toLowerCase().includes(q) ||
        campaign.message.toLowerCase().includes(q)
      )
    }
    return true
  })

  const filteredUsers = users.filter(user => {
    if (!userSearchQuery) return true
    const q = userSearchQuery.toLowerCase()
    const name = `${user.first_name || ''} ${user.last_name || ''}`.trim().toLowerCase()
    return name.includes(q) || user.email.toLowerCase().includes(q)
  })

  const stats = {
    total: campaigns.length,
    sent: campaigns.filter(c => c.status === 'sent').length,
    scheduled: campaigns.filter(c => c.status === 'scheduled').length,
    drafts: campaigns.filter(c => c.status === 'draft').length,
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Bell className="h-7 w-7 text-blue-600" />
            Push Notification Campaigns
          </h1>
          <p className="text-gray-600">Create and manage push notification campaigns</p>
        </div>
        <Button onClick={() => setShowCreateModal(true)}>
          <Plus className="h-4 w-4 mr-2" />
          New Campaign
        </Button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-blue-50 rounded-full">
              <Bell className="h-6 w-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Campaigns</p>
              <p className="text-2xl font-bold text-gray-900">{stats.total}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-green-200 bg-green-50/30">
          <div className="flex items-center">
            <div className="p-3 bg-green-100 rounded-full">
              <CheckCircle className="h-6 w-6 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Sent</p>
              <p className="text-2xl font-bold text-green-600">{stats.sent}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-yellow-200 bg-yellow-50/30">
          <div className="flex items-center">
            <div className="p-3 bg-yellow-100 rounded-full">
              <Clock className="h-6 w-6 text-yellow-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Scheduled</p>
              <p className="text-2xl font-bold text-yellow-600">{stats.scheduled}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-gray-100 rounded-full">
              <AlertCircle className="h-6 w-6 text-gray-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Drafts</p>
              <p className="text-2xl font-bold text-gray-600">{stats.drafts}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg border border-gray-200">
        <div className="flex flex-wrap gap-4 items-center">
          <div className="flex-1 min-w-[200px]">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search campaigns..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
          </div>
          <select
            className="h-10 rounded-md border border-input bg-background px-3 text-sm"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="all">All statuses</option>
            <option value="draft">Draft</option>
            <option value="scheduled">Scheduled</option>
            <option value="sending">Sending</option>
            <option value="sent">Sent</option>
            <option value="failed">Failed</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>
      </div>

      {/* Campaigns List */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-500">Loading campaigns...</div>
        ) : filteredCampaigns.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <Bell className="h-12 w-12 mx-auto text-gray-300 mb-4" />
            <p>No campaigns found</p>
            <p className="text-sm text-gray-400 mt-1">Create your first campaign to get started</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200">
            {filteredCampaigns.map((campaign) => (
              <div key={campaign.id} className="p-6 hover:bg-gray-50 transition-colors">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <h3 className="text-lg font-semibold text-gray-900">{campaign.title}</h3>
                      <StatusBadge status={campaign.status} />
                      <AudienceBadge audience={campaign.target_audience} />
                    </div>
                    <p className="text-gray-700 mb-3">{campaign.message}</p>
                    <div className="flex flex-wrap gap-4 text-sm text-gray-500">
                      <span>Created: {new Date(campaign.created_at).toLocaleString()}</span>
                      {campaign.sent_at && (
                        <span>Sent: {new Date(campaign.sent_at).toLocaleString()}</span>
                      )}
                      {campaign.scheduled_at && (
                        <span>Scheduled: {new Date(campaign.scheduled_at).toLocaleString()}</span>
                      )}
                      {campaign.total_recipients > 0 && (
                        <>
                          <span className="text-green-600">✓ {campaign.sent_count} sent</span>
                          {campaign.failed_count > 0 && (
                            <span className="text-red-600">✗ {campaign.failed_count} failed</span>
                          )}
                        </>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Create Campaign Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-3xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-200 flex items-center justify-between sticky top-0 bg-white">
              <h2 className="text-xl font-bold text-gray-900">Create New Campaign</h2>
              <button
                onClick={() => {
                  setShowCreateModal(false)
                  resetForm()
                }}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-6 w-6" />
              </button>
            </div>

            <div className="p-6 space-y-6">
              {/* Title */}
              <Input
                label="Campaign Title *"
                placeholder="Enter campaign title"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              />

              {/* Message */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Message *
                </label>
                <textarea
                  className="w-full min-h-[120px] rounded-md border border-input bg-background px-3 py-2 text-sm"
                  placeholder="Enter notification message"
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                />
              </div>

              {/* Target Audience */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-3">
                  Target Audience *
                </label>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <button
                    onClick={() => {
                      setFormData({ ...formData, target_audience: 'all_users', target_user_ids: [] })
                      setShowUserSelector(false)
                    }}
                    className={`p-4 rounded-lg border-2 transition-all ${
                      formData.target_audience === 'all_users'
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <Users className="h-6 w-6 mx-auto mb-2" />
                    <p className="font-medium">All Users</p>
                    <p className="text-xs text-gray-500 mt-1">Send to all users</p>
                  </button>
                  <button
                    onClick={() => {
                      setFormData({ ...formData, target_audience: 'all_vendors', target_user_ids: [] })
                      setShowUserSelector(false)
                    }}
                    className={`p-4 rounded-lg border-2 transition-all ${
                      formData.target_audience === 'all_vendors'
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <Store className="h-6 w-6 mx-auto mb-2" />
                    <p className="font-medium">All Vendors</p>
                    <p className="text-xs text-gray-500 mt-1">Send to all vendors</p>
                  </button>
                  <button
                    onClick={() => {
                      setFormData({ ...formData, target_audience: 'specific_users' })
                      setShowUserSelector(true)
                      loadUsers()
                    }}
                    className={`p-4 rounded-lg border-2 transition-all ${
                      formData.target_audience === 'specific_users'
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <UserCheck className="h-6 w-6 mx-auto mb-2" />
                    <p className="font-medium">Specific Users</p>
                    <p className="text-xs text-gray-500 mt-1">Select users</p>
                  </button>
                </div>
              </div>

              {/* User Selector */}
              {formData.target_audience === 'specific_users' && showUserSelector && (
                <div className="border border-gray-200 rounded-lg p-4 bg-gray-50">
                  <div className="flex items-center justify-between mb-3">
                    <p className="text-sm font-medium">
                      Selected: {formData.target_user_ids.length} users
                    </p>
                    <Input
                      placeholder="Search users..."
                      value={userSearchQuery}
                      onChange={(e) => setUserSearchQuery(e.target.value)}
                      className="max-w-xs"
                    />
                  </div>
                  <div className="max-h-60 overflow-y-auto space-y-2">
                    {loadingUsers ? (
                      <p className="text-sm text-gray-500">Loading users...</p>
                    ) : filteredUsers.length === 0 ? (
                      <p className="text-sm text-gray-500">No users found</p>
                    ) : (
                      filteredUsers.map((user) => {
                        const isSelected = formData.target_user_ids.includes(user.user_id)
                        return (
                          <button
                            key={user.user_id}
                            onClick={() => toggleUserSelection(user.user_id)}
                            className={`w-full p-3 rounded-lg border text-left transition ${
                              isSelected
                                ? 'border-blue-500 bg-blue-50'
                                : 'border-gray-200 hover:border-gray-300'
                            }`}
                          >
                            <p className="font-medium">
                              {user.first_name || user.last_name
                                ? `${user.first_name || ''} ${user.last_name || ''}`.trim()
                                : 'No name'}
                            </p>
                            <p className="text-sm text-gray-500">{user.email}</p>
                          </button>
                        )
                      })
                    )}
                  </div>
                </div>
              )}

              {/* CTA Section */}
              <div className="border-t border-gray-200 pt-4">
                <h3 className="text-sm font-medium text-gray-700 mb-3">Call-to-Action (Optional)</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <Input
                    label="CTA Button Text"
                    placeholder="e.g., View Details"
                    value={formData.cta_text}
                    onChange={(e) => setFormData({ ...formData, cta_text: e.target.value })}
                  />
                  <Input
                    label="CTA URL"
                    placeholder="https://example.com"
                    value={formData.cta_url}
                    onChange={(e) => setFormData({ ...formData, cta_url: e.target.value })}
                  />
                </div>
              </div>

              {/* Image URL */}
              <Input
                label="Image URL (Optional)"
                placeholder="https://example.com/image.jpg"
                value={formData.image_url}
                onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
              />

              {/* Schedule or Send Immediately */}
              <div className="border-t border-gray-200 pt-4">
                <label className="flex items-center gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.send_immediately}
                    onChange={(e) => setFormData({ ...formData, send_immediately: e.target.checked })}
                    className="h-4 w-4 text-blue-600"
                  />
                  <span className="text-sm font-medium">Send immediately</span>
                </label>
                {!formData.send_immediately && (
                  <div className="mt-4">
                    <Input
                      type="datetime-local"
                      label="Schedule Date & Time"
                      value={formData.scheduled_at}
                      onChange={(e) => setFormData({ ...formData, scheduled_at: e.target.value })}
                    />
                  </div>
                )}
              </div>

              {/* Actions */}
              <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
                <Button
                  variant="outline"
                  onClick={() => {
                    setShowCreateModal(false)
                    resetForm()
                  }}
                >
                  Cancel
                </Button>
                <Button onClick={sendCampaign} loading={sending}>
                  <Send className="h-4 w-4 mr-2" />
                  {formData.send_immediately ? 'Send Now' : 'Schedule Campaign'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    draft: 'bg-gray-100 text-gray-700',
    scheduled: 'bg-yellow-100 text-yellow-700',
    sending: 'bg-blue-100 text-blue-700',
    sent: 'bg-green-100 text-green-700',
    failed: 'bg-red-100 text-red-700',
    cancelled: 'bg-gray-100 text-gray-600',
  }
  return (
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors[status] || colors.draft}`}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  )
}

function AudienceBadge({ audience }: { audience: string }) {
  const labels: Record<string, string> = {
    all_users: 'All Users',
    all_vendors: 'All Vendors',
    specific_users: 'Specific Users',
  }
  return (
    <span className="px-2 py-1 bg-purple-100 text-purple-700 rounded text-xs font-medium">
      {labels[audience] || audience}
    </span>
  )
}
