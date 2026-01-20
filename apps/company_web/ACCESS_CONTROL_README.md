# Access Control System Documentation

## Overview

The Access Control system provides role-based access control (RBAC) for the company web admin portal. It allows super admins to manage admin users, assign roles, and control permissions.

## Features

### ✅ Super Admin Functionality
- **Super Admin Email**: `admin@saralevents.com` is the default super admin
- **Full Access**: Super admin can add, edit, and manage all admin users
- **Role Management**: Super admin can change any user's role at any time
- **User Status**: Super admin can activate/deactivate users

### ✅ User Management
- **Add Admin Users**: Super admin can add new admin users by email
- **Default Role**: All new users are assigned "Viewer" role by default
- **Automatic Linking**: When a user signs up/signs in with an email that exists in `admin_users`, their `user_id` is automatically linked
- **Last Login Tracking**: System tracks when each admin user last logged in

### ✅ Role Permissions Matrix
- **6 Roles**: super_admin, admin, support, finance, marketing, viewer
- **10 Resources**: dashboard, orders, users, vendors, services, reviews, support_tickets, marketing, analytics, settings
- **4 Permissions**: view, create, edit, delete
- **Visual Matrix**: Interactive table showing permissions for each role/resource combination

## Database Schema

### admin_users Table

```sql
CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('super_admin', 'admin', 'support', 'finance', 'marketing', 'viewer')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_login TIMESTAMPTZ
);
```

## Setup Instructions

### 1. Run Database Migration

Execute the SQL script in your Supabase SQL Editor:

```bash
apps/company_web/admin_users_schema.sql
```

This will:
- Create the `admin_users` table
- Set up indexes for performance
- Enable RLS (Row Level Security)
- Create RLS policies
- Insert the super admin user (`admin@saralevents.com`)

### 2. Verify Super Admin

1. Sign in with `admin@saralevents.com`
2. Navigate to `/dashboard/access-control`
3. You should see the super admin user listed
4. You can now add other admin users

## How It Works

### Adding New Admin Users

1. **Super admin** clicks "Add Admin User"
2. Enters email address and optional full name
3. Selects role (default: Viewer)
4. System creates entry in `admin_users` table
5. User receives email (if email service configured) or must sign up manually
6. When user signs up/signs in with that email, their `user_id` is automatically linked

### Automatic User Linking

When a user signs in:
1. System checks if their email exists in `admin_users` table
2. If found and `user_id` is null, it links the current auth user's ID
3. Updates `last_login` timestamp
4. User can now access admin portal based on their role

### Role Permissions

Each role has specific permissions:

- **Super Admin**: Full access to everything (view, create, edit, delete)
- **Admin**: View and edit access to most resources
- **Support**: View and edit access to orders, reviews, support tickets
- **Finance**: View-only access to orders, users, vendors, analytics
- **Marketing**: Full access to marketing, view access to others
- **Viewer**: View-only access to all resources

## Usage

### Access Control Page

Navigate to: `/dashboard/access-control`

**Tabs:**
1. **Admin Users**: List of all admin users with their roles and status
2. **Role Permissions Matrix**: Visual table showing permissions for each role

### Adding a User

1. Click "Add Admin User" button
2. Enter email address (required)
3. Enter full name (optional)
4. Select role (default: Viewer)
5. Click "Add User"
6. User will need to sign up with that email to access the portal

### Changing a User's Role

1. Click the edit icon next to the user
2. Select new role from dropdown
3. Role is saved automatically

### Activating/Deactivating Users

1. Click the X/Check icon next to the user
2. User status toggles between Active/Inactive
3. Inactive users cannot access the admin portal

## Security Features

1. **Super Admin Only**: Only super admin can access the access control page
2. **RLS Policies**: Database-level security policies
3. **Email Verification**: Users must sign up with the exact email
4. **Role Validation**: Roles are validated at database level
5. **Status Check**: Only active users can access the portal

## API Functions

### `linkAdminUser()`
Links current authenticated user with `admin_users` table based on email.

### `updateAdminUserLastLogin()`
Updates the `last_login` timestamp for the current user.

### `isSuperAdmin()`
Checks if current user is super admin.

### `getCurrentUserRole()`
Gets the current user's admin role.

## Troubleshooting

### User Cannot Access Admin Portal

1. Check if user exists in `admin_users` table
2. Verify `is_active` is `true`
3. Ensure user signed up with the exact email in `admin_users`
4. Check if `user_id` is linked (should be populated after sign-in)

### Super Admin Cannot Add Users

1. Verify you're signed in as `admin@saralevents.com`
2. Check browser console for errors
3. Verify `admin_users` table exists
4. Check RLS policies are set correctly

### User ID Not Linking

1. Ensure user signed up/signed in with the exact email
2. Check `linkAdminUser()` function is being called
3. Verify RLS policies allow updates
4. Check browser console for errors

## Future Enhancements

- [ ] Email invitations for new admin users
- [ ] Bulk user import
- [ ] Custom permission sets
- [ ] Audit log for role changes
- [ ] Two-factor authentication
- [ ] Session management
