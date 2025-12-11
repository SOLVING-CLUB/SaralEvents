// Role-Based Access Control (RBAC) System

export type Role = 'super_admin' | 'admin' | 'support' | 'finance' | 'marketing' | 'viewer'

export type Permission = 'view' | 'create' | 'edit' | 'delete'

export type Resource = 
  | 'dashboard'
  | 'orders'
  | 'users'
  | 'vendors'
  | 'services'
  | 'reviews'
  | 'support_tickets'
  | 'marketing'
  | 'analytics'
  | 'settings'

// Role hierarchy and permissions
export const rolePermissions: Record<Role, Record<Resource, Permission[]>> = {
  super_admin: {
    dashboard: ['view', 'create', 'edit', 'delete'],
    orders: ['view', 'create', 'edit', 'delete'],
    users: ['view', 'create', 'edit', 'delete'],
    vendors: ['view', 'create', 'edit', 'delete'],
    services: ['view', 'create', 'edit', 'delete'],
    reviews: ['view', 'create', 'edit', 'delete'],
    support_tickets: ['view', 'create', 'edit', 'delete'],
    marketing: ['view', 'create', 'edit', 'delete'],
    analytics: ['view', 'create', 'edit', 'delete'],
    settings: ['view', 'create', 'edit', 'delete'],
  },
  admin: {
    dashboard: ['view', 'edit'],
    orders: ['view', 'edit'],
    users: ['view', 'edit'],
    vendors: ['view', 'edit'],
    services: ['view', 'edit'],
    reviews: ['view', 'edit'],
    support_tickets: ['view', 'edit'],
    marketing: ['view', 'edit'],
    analytics: ['view'],
    settings: ['view'],
  },
  support: {
    dashboard: ['view'],
    orders: ['view', 'edit'],
    users: ['view'],
    vendors: ['view'],
    services: ['view'],
    reviews: ['view', 'edit'],
    support_tickets: ['view', 'create', 'edit'],
    marketing: [],
    analytics: ['view'],
    settings: [],
  },
  finance: {
    dashboard: ['view'],
    orders: ['view'],
    users: ['view'],
    vendors: ['view'],
    services: ['view'],
    reviews: [],
    support_tickets: ['view'],
    marketing: [],
    analytics: ['view'],
    settings: [],
  },
  marketing: {
    dashboard: ['view'],
    orders: ['view'],
    users: ['view'],
    vendors: ['view'],
    services: ['view'],
    reviews: ['view'],
    support_tickets: [],
    marketing: ['view', 'create', 'edit', 'delete'],
    analytics: ['view'],
    settings: [],
  },
  viewer: {
    dashboard: ['view'],
    orders: ['view'],
    users: ['view'],
    vendors: ['view'],
    services: ['view'],
    reviews: ['view'],
    support_tickets: ['view'],
    marketing: ['view'],
    analytics: ['view'],
    settings: [],
  },
}

export function hasPermission(role: Role, resource: Resource, permission: Permission): boolean {
  const perms = rolePermissions[role]?.[resource] || []
  return perms.includes(permission)
}

export function canAccess(role: Role, resource: Resource): boolean {
  return hasPermission(role, resource, 'view')
}

export function getRoleDisplayName(role: Role): string {
  const names: Record<Role, string> = {
    super_admin: 'Super Admin',
    admin: 'Admin',
    support: 'Support',
    finance: 'Finance',
    marketing: 'Marketing',
    viewer: 'Viewer',
  }
  return names[role] || role
}

export function getRoleBadgeColor(role: Role): string {
  const colors: Record<Role, string> = {
    super_admin: 'bg-purple-100 text-purple-800',
    admin: 'bg-blue-100 text-blue-800',
    support: 'bg-green-100 text-green-800',
    finance: 'bg-yellow-100 text-yellow-800',
    marketing: 'bg-pink-100 text-pink-800',
    viewer: 'bg-gray-100 text-gray-800',
  }
  return colors[role] || 'bg-gray-100 text-gray-800'
}

