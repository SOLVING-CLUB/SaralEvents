"use client"

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase'
import { 
  Shield, 
  Users, 
  UserPlus, 
  Settings, 
  Check, 
  X, 
  Edit2,
  Save,
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

interface AdminUser {
  id: string
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
const PERMISSIONS: Permission[] = ['view', 'create', 'edit', 'delete']

export default function AccessControlPage() {
  const supabase = createClient()
  const [adminUsers, setAdminUsers] = useState<AdminUser[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'users' | 'roles'>('users')
  const [editingUser, setEditingUser] = useState<string | null>(null)
  const [newUserEmail, setNewUserEmail] = useState('')
  const [newUserRole, setNewUserRole] = useState<Role>('viewer')
  const [showAddUser, setShowAddUser] = useState(false)

  useEffect(() => {
    loadAdminUsers()
  }, [])

  async function loadAdminUsers() {
    setLoading(true)
    setError(null)
    
    const { data, error } = await supabase
      .from('admin_users')
      .select('*')
      .order('created_at', { ascending: false })
    
    if (error) {
      if (error.code === '42P01') {
        // Table doesn't exist - show sample data
        setAdminUsers([
          {
            id: '1',
            email: 'admin@saralevents.com',
            full_name: 'Super Admin',
            role: 'super_admin',
            is_active: true,
            created_at: new Date().toISOString(),
            last_login: new Date().toISOString(),
          }
        ])
      } else {
        setError(error.message)
      }
    } else {
      setAdminUsers((data || []) as AdminUser[])
    }
    setLoading(false)
  }

  async function updateUserRole(userId: string, newRole: Role) {
    const { error } = await supabase
      .from('admin_users')
      .update({ role: newRole })
      .eq('id', userId)
    
    if (!error) {
      setAdminUsers(prev => prev.map(u => 
        u.id === userId ? { ...u, role: newRole } : u
      ))
      setEditingUser(null)
    }
  }

  async function toggleUserStatus(userId: string, currentStatus: boolean) {
    const { error } = await supabase
      .from('admin_users')
      .update({ is_active: !currentStatus })
      .eq('id', userId)
    
    if (!error) {
      setAdminUsers(prev => prev.map(u => 
        u.id === userId ? { ...u, is_active: !currentStatus } : u
      ))
    }
  }

  async function addAdminUser() {
    if (!newUserEmail.trim()) return
    
    const { error } = await supabase
      .from('admin_users')
      .insert({
        email: newUserEmail.trim(),
        role: newUserRole,
        is_active: true,
      })
    
    if (!error) {
      await loadAdminUsers()
      setNewUserEmail('')
      setNewUserRole('viewer')
      setShowAddUser(false)
    } else {
      setError(error.message)
    }
  }

  const stats = {
    total: adminUsers.length,
    active: adminUsers.filter(u => u.is_active).length,
    superAdmins: adminUsers.filter(u => u.role === 'super_admin').length,
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
        <Button onClick={() => setShowAddUser(true)}>
          <UserPlus className="h-4 w-4 mr-2" />
          Add Admin User
        </Button>
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

      {/* Add User Modal */}
      {showAddUser && (
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <h3 className="text-lg font-semibold mb-4">Add New Admin User</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="md:col-span-2">
              <Input
                placeholder="Email address"
                type="email"
                value={newUserEmail}
                onChange={(e) => setNewUserEmail(e.target.value)}
              />
            </div>
            <div>
              <select
                className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
                value={newUserRole}
                onChange={(e) => setNewUserRole(e.target.value as Role)}
              >
                {ROLES.map(role => (
                  <option key={role} value={role}>{getRoleDisplayName(role)}</option>
                ))}
              </select>
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <Button onClick={addAdminUser}>Add User</Button>
            <Button variant="outline" onClick={() => setShowAddUser(false)}>Cancel</Button>
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
            Admin Users
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

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-600">
          {error}
        </div>
      )}

      {activeTab === 'users' && (
        <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
          {loading ? (
            <div className="p-8 text-center text-gray-500">Loading users...</div>
          ) : adminUsers.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <Users className="h-12 w-12 mx-auto text-gray-300 mb-4" />
              <p>No admin users found</p>
              <p className="text-sm text-gray-400 mt-1">Add your first admin user to get started</p>
            </div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50 text-left">
                <tr>
                  <th className="p-3">User</th>
                  <th className="p-3">Role</th>
                  <th className="p-3">Status</th>
                  <th className="p-3">Last Login</th>
                  <th className="p-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {adminUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-gray-50">
                    <td className="p-3">
                      <div>
                        <p className="font-medium text-gray-900">{user.full_name || 'Unknown'}</p>
                        <p className="text-sm text-gray-500">{user.email}</p>
                      </div>
                    </td>
                    <td className="p-3">
                      {editingUser === user.id ? (
                        <select
                          className="text-sm border rounded px-2 py-1"
                          value={user.role}
                          onChange={(e) => updateUserRole(user.id, e.target.value as Role)}
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
                        ? new Date(user.last_login).toLocaleDateString() 
                        : 'Never'}
                    </td>
                    <td className="p-3">
                      <div className="flex gap-2">
                        {editingUser === user.id ? (
                          <button
                            onClick={() => setEditingUser(null)}
                            className="p-1 text-green-600 hover:bg-green-50 rounded"
                          >
                            <Save className="h-4 w-4" />
                          </button>
                        ) : (
                          <button
                            onClick={() => setEditingUser(user.id)}
                            className="p-1 text-blue-600 hover:bg-blue-50 rounded"
                          >
                            <Edit2 className="h-4 w-4" />
                          </button>
                        )}
                        <button
                          onClick={() => toggleUserStatus(user.id, user.is_active)}
                          className={`p-1 rounded ${
                            user.is_active 
                              ? 'text-red-600 hover:bg-red-50' 
                              : 'text-green-600 hover:bg-green-50'
                          }`}
                        >
                          {user.is_active ? <X className="h-4 w-4" /> : <Check className="h-4 w-4" />}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {activeTab === 'roles' && (
        <div className="bg-white rounded-lg border border-gray-200 overflow-x-auto">
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
                    {resource.replace('_', ' ')}
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
                                className={`px-1.5 py-0.5 rounded text-xs ${
                                  perm === 'view' ? 'bg-blue-100 text-blue-700' :
                                  perm === 'create' ? 'bg-green-100 text-green-700' :
                                  perm === 'edit' ? 'bg-yellow-100 text-yellow-700' :
                                  'bg-red-100 text-red-700'
                                }`}
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
            <p className="text-sm text-gray-600">
              <span className="font-medium">Legend:</span>
              <span className="ml-4 px-1.5 py-0.5 bg-blue-100 text-blue-700 rounded text-xs mr-1">V</span> View
              <span className="ml-3 px-1.5 py-0.5 bg-green-100 text-green-700 rounded text-xs mr-1">C</span> Create
              <span className="ml-3 px-1.5 py-0.5 bg-yellow-100 text-yellow-700 rounded text-xs mr-1">E</span> Edit
              <span className="ml-3 px-1.5 py-0.5 bg-red-100 text-red-700 rounded text-xs mr-1">D</span> Delete
            </p>
          </div>
        </div>
      )}
    </div>
  )
}

