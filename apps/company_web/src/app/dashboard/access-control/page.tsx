"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'
import { 
  Shield, 
  Users, 
  UserPlus, 
  Settings, 
  Check, 
  X, 
  Edit2,
  Save,
  AlertCircle,
  Loader2,
  Trash2
} from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { 
  Role, 
  Permission, 
  Resource, 
  rolePermissions, 
  getRoleDisplayName, 
  getRoleBadgeColor,
  hasPermission 
} from '@/lib/rbac'

const SUPER_ADMIN_EMAIL = 'admin@saralevents.com'

interface AdminUser {
  id: string
  user_id: string | null
  email: string
  full_name: string | null
  role: Role
  is_active: boolean
  created_at: string
  last_login: string | null
}

const ROLES: Role[] = ['super_admin', 'admin', 'support', 'finance', 'marketing', 'viewer']
const RESOURCES: Resource[] = [
  'dashboard', 'orders', 'users', 'vendors', 'services', 
  'reviews', 'support_tickets', 'marketing', 'analytics', 'settings'
]

export default function AccessControlPage() {
  const supabase = createClient()
  const { user: currentUser } = useAuth()
  const [adminUsers, setAdminUsers] = useState<AdminUser[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'users' | 'roles'>('users')
  const [editingUser, setEditingUser] = useState<string | null>(null)
  const [newUserEmail, setNewUserEmail] = useState('')
  const [newUserFullName, setNewUserFullName] = useState('')
  const [newUserRole, setNewUserRole] = useState<Role>('viewer')
  const [showAddUser, setShowAddUser] = useState(false)
  const [isSuperAdmin, setIsSuperAdmin] = useState(false)
  const [processing, setProcessing] = useState(false)
  const [showCleanupConfirm, setShowCleanupConfirm] = useState(false)
  const [cleanupConfirmText, setCleanupConfirmText] = useState('')

  useEffect(() => {
    checkSuperAdmin()
    loadAdminUsers()
  }, [currentUser])

  async function checkSuperAdmin() {
    if (currentUser?.email === SUPER_ADMIN_EMAIL) {
      setIsSuperAdmin(true)
    } else {
      // Check if current user is super admin in admin_users table
      const { data: { user } } = await supabase.auth.getUser()
      if (user) {
        const { data } = await supabase
          .from('admin_users')
          .select('role')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle()
        
        setIsSuperAdmin(data?.role === 'super_admin' || user.email === SUPER_ADMIN_EMAIL)
      }
    }
  }

  async function loadAdminUsers() {
    setLoading(true)
    setError(null)
    
    try {
      // First, ensure super admin exists
      await ensureSuperAdminExists()

      // Fetch admin users with auth.users data
      const { data, error: fetchError } = await supabase
        .from('admin_users')
        .select('*')
        .order('created_at', { ascending: false })
      
      if (fetchError) {
        if (fetchError.code === '42P01') {
          // Table doesn't exist - create it
          setError('Admin users table does not exist. Please run admin_users_schema.sql in Supabase.')
          return
        }
        throw fetchError
      }

      const rows = (data || []) as AdminUser[]
      setAdminUsers(rows)
    } catch (err: any) {
      console.error('Error loading admin users:', err)
      setError(err.message || 'Failed to load admin users')
    } finally {
      setLoading(false)
    }
  }

  async function ensureSuperAdminExists() {
    // Check if super admin exists
    const { data: existingSuperAdmin, error: findErr } = await supabase
      .from('admin_users')
      .select('*')
      .eq('email', SUPER_ADMIN_EMAIL)
      .maybeSingle()

    if (findErr?.code === '42P01') {
      throw new Error('admin_users table missing. Run admin_users_schema.sql in Supabase.')
    }

    if (!existingSuperAdmin) {
      const { error: insertError } = await supabase
        .from('admin_users')
        .insert({
          email: SUPER_ADMIN_EMAIL,
          user_id: null,
          full_name: 'Super Admin',
          role: 'super_admin',
          is_active: true,
        })

      if (insertError && insertError.code !== '23505') { // Ignore duplicate key error
        throw new Error(insertError.message)
      }
    }
  }

  async function addAdminUser() {
    if (!newUserEmail.trim()) {
      setError('Email is required')
      return
    }

    if (!isSuperAdmin) {
      setError('Only super admin can add new admin users')
      return
    }

    setProcessing(true)
    setError(null)
    setSuccess(null)

    try {
      // Check if user already exists in admin_users
      const { data: existingAdmin } = await supabase
        .from('admin_users')
        .select('*')
        .eq('email', newUserEmail.trim().toLowerCase())
        .maybeSingle()

      if (existingAdmin) {
        setError('This email is already registered as an admin user')
        setProcessing(false)
        return
      }

      // Try to find existing auth user by checking current session or using RPC
      // For now, we'll create admin_users entry without user_id
      // The user_id will be populated when the user signs up with that email
      let authUserId: string | null = null
      
      // Check if current user matches the email (they're adding themselves)
      if (currentUser?.email?.toLowerCase() === newUserEmail.trim().toLowerCase()) {
        authUserId = currentUser.id
      }
      
      // Note: Creating auth users requires admin API or Edge Function
      // For now, we'll create the admin_users entry and the user can sign up later
      // The user_id will be linked when they sign up with the same email

      // Create admin_users entry with default role 'viewer'
      const { error: insertError } = await supabase
        .from('admin_users')
        .insert({
          email: newUserEmail.trim().toLowerCase(),
          user_id: authUserId,
          full_name: newUserFullName.trim() || null,
          role: newUserRole, // Default is 'viewer' but can be changed
          is_active: true,
        })

      if (insertError) {
        throw new Error(`Failed to add admin user: ${insertError.message}`)
      }

      setSuccess(`Admin user ${newUserEmail} added successfully with role "${getRoleDisplayName(newUserRole)}". ${authUserId ? 'User is already registered.' : 'User will need to sign up with this email to access the admin portal.'}`)
      await loadAdminUsers()
      setNewUserEmail('')
      setNewUserFullName('')
      setNewUserRole('viewer')
      setShowAddUser(false)
    } catch (err: any) {
      console.error('Error adding admin user:', err)
      setError(err.message || 'Failed to add admin user')
    } finally {
      setProcessing(false)
    }
  }

  async function updateUserRole(userId: string, newRole: Role) {
    if (!isSuperAdmin) {
      setError('Only super admin can change user roles')
      return
    }

    setError(null)
    setSuccess(null)

    const { error } = await supabase
      .from('admin_users')
      .update({ role: newRole, updated_at: new Date().toISOString() })
      .eq('id', userId)
    
    if (error) {
      setError(`Failed to update role: ${error.message}`)
    } else {
      setSuccess('Role updated successfully')
      setAdminUsers(prev => prev.map(u => 
        u.id === userId ? { ...u, role: newRole } : u
      ))
      setEditingUser(null)
      setTimeout(() => setSuccess(null), 3000)
    }
  }

  async function toggleUserStatus(userId: string, currentStatus: boolean) {
    if (!isSuperAdmin) {
      setError('Only super admin can change user status')
      return
    }

    setError(null)
    setSuccess(null)

    const { error } = await supabase
      .from('admin_users')
      .update({ is_active: !currentStatus, updated_at: new Date().toISOString() })
      .eq('id', userId)
    
    if (error) {
      setError(`Failed to update status: ${error.message}`)
    } else {
      setSuccess(`User ${!currentStatus ? 'activated' : 'deactivated'} successfully`)
      setAdminUsers(prev => prev.map(u => 
        u.id === userId ? { ...u, is_active: !currentStatus } : u
      ))
      setTimeout(() => setSuccess(null), 3000)
    }
  }

  async function cleanupOrphanedUsers() {
    if (!isSuperAdmin) {
      setError('Only super admin can perform cleanup')
      return
    }

    if (cleanupConfirmText !== 'DELETE ALL') {
      setError('Please type "DELETE ALL" to confirm cleanup')
      return
    }

    setProcessing(true)
    setError(null)
    setSuccess(null)

    try {
      // Delete orphaned admin_users entries (those with null user_id)
      // Keep super admin safe - delete all except super admin
      const usersToDelete = adminUsers.filter(u => 
        u.email.toLowerCase() !== SUPER_ADMIN_EMAIL.toLowerCase() && 
        (!u.user_id || u.user_id === null)
      )

      let deletedCount = 0
      for (const user of usersToDelete) {
        const { error: deleteError } = await supabase
          .from('admin_users')
          .delete()
          .eq('id', user.id)

        if (!deleteError) {
          deletedCount++
        }
      }

      setSuccess(`Cleaned up ${deletedCount} orphaned admin_users entries. Note: To delete auth.users accounts (like karthikeyabalaji123@gmail.com), you must run the SQL script cleanup_orphaned_auth_users.sql in Supabase SQL Editor.`)
      await loadAdminUsers()
      setShowCleanupConfirm(false)
      setCleanupConfirmText('')
    } catch (err: any) {
      console.error('Error cleaning up users:', err)
      setError(err.message || 'Failed to cleanup users')
    } finally {
      setProcessing(false)
    }
  }

  const stats = {
    total: adminUsers.length,
    active: adminUsers.filter(u => u.is_active).length,
    superAdmins: adminUsers.filter(u => u.role === 'super_admin').length,
  }

  if (!isSuperAdmin && currentUser?.email !== SUPER_ADMIN_EMAIL) {
    return (
      <div className="space-y-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <div className="flex items-start">
            <AlertCircle className="h-6 w-6 text-yellow-600 mt-0.5 mr-3" />
            <div>
              <h2 className="text-lg font-semibold text-yellow-900">Access Restricted</h2>
              <p className="text-yellow-800 mt-1">
                Only super admin can access this page. Please contact the super admin to grant you access.
              </p>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Shield className="h-7 w-7 text-purple-600" />
            Role-Based Access Control
          </h1>
          <p className="text-gray-600">Manage admin team roles and permissions</p>
        </div>
        {isSuperAdmin && (
          <div className="flex gap-2">
            <Button onClick={() => setShowAddUser(true)} disabled={processing}>
              <UserPlus className="h-4 w-4 mr-2" />
              Add Admin User
            </Button>
          </div>
        )}
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-blue-50 rounded-full">
              <Users className="h-6 w-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Total Admins</p>
              <p className="text-2xl font-bold text-gray-900">{stats.total}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-green-50 rounded-full">
              <Check className="h-6 w-6 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Active</p>
              <p className="text-2xl font-bold text-green-600">{stats.active}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center">
            <div className="p-3 bg-purple-50 rounded-full">
              <Shield className="h-6 w-6 text-purple-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm text-gray-600">Super Admins</p>
              <p className="text-2xl font-bold text-purple-600">{stats.superAdmins}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Messages */}
      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-600 flex items-start">
          <AlertCircle className="h-5 w-5 mr-2 mt-0.5 flex-shrink-0" />
          <div className="flex-1">{error}</div>
          <button onClick={() => setError(null)} className="ml-2 text-red-400 hover:text-red-600">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {success && (
        <div className="p-4 bg-green-50 border border-green-200 rounded-lg text-green-600 flex items-start">
          <Check className="h-5 w-5 mr-2 mt-0.5 flex-shrink-0" />
          <div className="flex-1">{success}</div>
          <button onClick={() => setSuccess(null)} className="ml-2 text-green-400 hover:text-green-600">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {/* Cleanup Confirmation Modal temporarily disabled */}

      {/* Add User Modal */}
      {showAddUser && isSuperAdmin && (
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <h3 className="text-lg font-semibold mb-4">Add New Admin User</h3>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email Address *</label>
              <Input
                placeholder="user@example.com"
                type="email"
                value={newUserEmail}
                onChange={(e) => setNewUserEmail(e.target.value)}
                disabled={processing}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Full Name (Optional)</label>
              <Input
                placeholder="John Doe"
                value={newUserFullName}
                onChange={(e) => setNewUserFullName(e.target.value)}
                disabled={processing}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
              <select
                className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
                value={newUserRole}
                onChange={(e) => setNewUserRole(e.target.value as Role)}
                disabled={processing}
              >
                {ROLES.map(role => (
                  <option key={role} value={role}>{getRoleDisplayName(role)}</option>
                ))}
              </select>
              <p className="text-xs text-gray-500 mt-1">
                Default role is "Viewer". Super admin can change this later.
              </p>
            </div>
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
              <p className="text-sm text-blue-800">
                <strong>Note:</strong> The user will need to sign up with this email address to access the admin portal. 
                Their user_id will be automatically linked when they sign in.
              </p>
            </div>
          </div>
          <div className="flex gap-2 mt-6">
            <Button onClick={addAdminUser} disabled={processing || !newUserEmail.trim()}>
              {processing ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Adding...
                </>
              ) : (
                <>
                  <UserPlus className="h-4 w-4 mr-2" />
                  Add User
                </>
              )}
            </Button>
            <Button variant="outline" onClick={() => {
              setShowAddUser(false)
              setNewUserEmail('')
              setNewUserFullName('')
              setNewUserRole('viewer')
              setError(null)
            }} disabled={processing}>
              Cancel
            </Button>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <div className="flex gap-4">
          <button
            className={`px-4 py-2 font-medium text-sm border-b-2 transition-colors ${
              activeTab === 'users' 
                ? 'border-blue-600 text-blue-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('users')}
          >
            <Users className="h-4 w-4 inline mr-2" />
            Admin Users ({adminUsers.length})
          </button>
          <button
            className={`px-4 py-2 font-medium text-sm border-b-2 transition-colors ${
              activeTab === 'roles' 
                ? 'border-blue-600 text-blue-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('roles')}
          >
            <Settings className="h-4 w-4 inline mr-2" />
            Role Permissions Matrix
          </button>
        </div>
      </div>

      {activeTab === 'users' && (
        <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
          {loading ? (
            <div className="p-8 text-center text-gray-500">
              <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2" />
              <p>Loading users...</p>
            </div>
          ) : adminUsers.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <Users className="h-12 w-12 mx-auto text-gray-300 mb-4" />
              <p>No admin users found</p>
              <p className="text-sm text-gray-400 mt-1">Add your first admin user to get started</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead className="bg-gray-50 text-left">
                  <tr>
                    <th className="p-3">User</th>
                    <th className="p-3">Role</th>
                    <th className="p-3">Status</th>
                    <th className="p-3">Last Login</th>
                    {isSuperAdmin && <th className="p-3">Actions</th>}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {adminUsers.map((user) => (
                    <tr key={user.id} className="hover:bg-gray-50">
                      <td className="p-3">
                        <div>
                          <p className="font-medium text-gray-900">{user.full_name || 'No name'}</p>
                          <p className="text-sm text-gray-500">{user.email}</p>
                          {user.email === SUPER_ADMIN_EMAIL && (
                            <span className="inline-block mt-1 px-2 py-0.5 bg-purple-100 text-purple-700 text-xs rounded">
                              Super Admin
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="p-3">
                        {editingUser === user.id && isSuperAdmin ? (
                          <select
                            className="text-sm border rounded px-2 py-1"
                            value={user.role}
                            onChange={(e) => updateUserRole(user.id, e.target.value as Role)}
                            onBlur={() => setEditingUser(null)}
                            autoFocus
                          >
                            {ROLES.map(role => (
                              <option key={role} value={role}>{getRoleDisplayName(role)}</option>
                            ))}
                          </select>
                        ) : (
                          <span className={`px-2 py-1 rounded text-xs font-medium ${getRoleBadgeColor(user.role)}`}>
                            {getRoleDisplayName(user.role)}
                          </span>
                        )}
                      </td>
                      <td className="p-3">
                        <span className={`px-2 py-1 rounded text-xs ${
                          user.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                        }`}>
                          {user.is_active ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td className="p-3 text-gray-500 text-xs">
                        {user.last_login 
                          ? new Date(user.last_login).toLocaleDateString() + ' ' + new Date(user.last_login).toLocaleTimeString()
                          : 'Never'}
                      </td>
                      {isSuperAdmin && (
                        <td className="p-3">
                          <div className="flex gap-2">
                            {editingUser === user.id ? (
                              <button
                                onClick={() => setEditingUser(null)}
                                className="p-1 text-gray-600 hover:bg-gray-100 rounded"
                                title="Cancel"
                              >
                                <X className="h-4 w-4" />
                              </button>
                            ) : (
                              <button
                                onClick={() => setEditingUser(user.id)}
                                className="p-1 text-blue-600 hover:bg-blue-50 rounded"
                                title="Edit role"
                              >
                                <Edit2 className="h-4 w-4" />
                              </button>
                            )}
                            {user.email !== SUPER_ADMIN_EMAIL && (
                              <button
                                onClick={() => toggleUserStatus(user.id, user.is_active)}
                                className={`p-1 rounded ${
                                  user.is_active 
                                    ? 'text-red-600 hover:bg-red-50' 
                                    : 'text-green-600 hover:bg-green-50'
                                }`}
                                title={user.is_active ? 'Deactivate' : 'Activate'}
                              >
                                {user.is_active ? <X className="h-4 w-4" /> : <Check className="h-4 w-4" />}
                              </button>
                            )}
                          </div>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {activeTab === 'roles' && (
        <div className="bg-white rounded-lg border border-gray-200 overflow-x-auto">
          <div className="p-4 bg-blue-50 border-b border-gray-200">
            <p className="text-sm text-blue-800">
              <strong>Note:</strong> This matrix shows the permissions for each role. Super Admin has full access to all resources.
            </p>
          </div>
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="p-3 text-left font-semibold">Resource</th>
                {ROLES.map(role => (
                  <th key={role} className="p-3 text-center">
                    <span className={`px-2 py-1 rounded text-xs font-medium ${getRoleBadgeColor(role)}`}>
                      {getRoleDisplayName(role)}
                    </span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {RESOURCES.map(resource => (
                <tr key={resource} className="hover:bg-gray-50">
                  <td className="p-3 font-medium text-gray-900 capitalize">
                    {resource.replace(/_/g, ' ')}
                  </td>
                  {ROLES.map(role => {
                    const perms = rolePermissions[role]?.[resource] || []
                    return (
                      <td key={`${resource}-${role}`} className="p-3 text-center">
                        <div className="flex flex-wrap justify-center gap-1">
                          {perms.length === 0 ? (
                            <span className="text-gray-300">—</span>
                          ) : (
                            perms.map(perm => (
                              <span 
                                key={perm}
                                className={`px-1.5 py-0.5 rounded text-xs font-medium ${
                                  perm === 'view' ? 'bg-blue-100 text-blue-700' :
                                  perm === 'create' ? 'bg-green-100 text-green-700' :
                                  perm === 'edit' ? 'bg-yellow-100 text-yellow-700' :
                                  'bg-red-100 text-red-700'
                                }`}
                                title={perm}
                              >
                                {perm[0].toUpperCase()}
                              </span>
                            ))
                          )}
                        </div>
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
          <div className="p-4 bg-gray-50 border-t border-gray-200">
            <p className="text-sm text-gray-600 mb-2">
              <span className="font-medium">Legend:</span>
            </p>
            <div className="flex flex-wrap gap-4 text-xs">
              <span><span className="px-1.5 py-0.5 bg-blue-100 text-blue-700 rounded font-medium mr-1">V</span> View</span>
              <span><span className="px-1.5 py-0.5 bg-green-100 text-green-700 rounded font-medium mr-1">C</span> Create</span>
              <span><span className="px-1.5 py-0.5 bg-yellow-100 text-yellow-700 rounded font-medium mr-1">E</span> Edit</span>
              <span><span className="px-1.5 py-0.5 bg-red-100 text-red-700 rounded font-medium mr-1">D</span> Delete</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
