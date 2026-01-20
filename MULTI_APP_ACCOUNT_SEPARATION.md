## Multi-app account separation (Company Web vs User App vs Vendor App)

### Core idea

Supabase Auth (`auth.users`) is **global per project**, so an email can only exist **once** there.
To support “separate accounts per app” **without conflicts**, we keep:

- **One auth identity** per email (`auth.users`)
- **Separate app account records** per app (your app tables)
- A lightweight **role marker** row per app in `user_roles`

### Tables (recommended)

- **Company Web (Admin Portal)**: `admin_users`
  - This is an **allowlist**: user can access company portal only if they exist here and are active.
  - Default role for any new admin record is `viewer`.

- **User App**: `user_profiles` (+ `user_roles` with role = `user`)
- **Vendor App**: `vendor_profiles` (+ `user_roles` with role = `vendor`)

### Login / Signup rules

#### Company Web

- On **sign in**:
  - Check `admin_users` by email:
    - not present → reject (“not invited”)
    - present but inactive → reject
    - present and active → allow sign-in
  - After sign-in: link `admin_users.user_id` (if missing) and ensure `user_roles(role='company')`.

- On **sign up**:
  - Still check allowlist in `admin_users`.
  - If Supabase returns “User already registered”, we treat this as:
    - the user is already a Supabase auth user (maybe from User App / Vendor App)
    - so we do **sign in** instead, and link the company portal account.

#### User App / Vendor App

- They should not rely on “auth user exists” to decide if the app account exists.
- After sign-in:
  - Ensure the app-specific profile exists (create if missing)
  - Ensure `user_roles` has the app role (insert if missing)

### Why this avoids conflicts

- Same email can use multiple apps because we **don’t create multiple auth users**.
- App ownership is decided by **your app tables** (`admin_users`, `user_profiles`, `vendor_profiles`) and `user_roles`.

