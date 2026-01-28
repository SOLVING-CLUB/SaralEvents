## Supabase Database Documentation

**Project database**: `postgres` (Supabase managed)  
**Schema snapshot generated at**: `2026-01-28T13:02:32.098969+00:00` (UTC)  
**Snapshot source**: Supabase SQL editor introspection query (`schema_introspection_snapshot`)

This document is intended to be a **single, very detailed reference** for your Supabase project.  
You can use it whenever you need to:

- Understand what data lives where.
- See how security and RLS are configured.
- Remember how to call the APIs (REST, RPC, GraphQL).
- Regenerate or extend documentation in the future.

---

## Table of Contents

- **1. Schemas – High-Level Overview**
- **2. Auth Schema (`auth`)**
  - 2.1 Purpose and responsibilities  
  - 2.2 Key tables and typical usage  
  - 2.3 Example queries and API calls  
- **3. Public Schema (`public`)**
  - 3.1 User & role management  
  - 3.2 Vendors & services  
  - 3.3 Events & bookings  
  - 3.4 Guests, invitations & checklists  
  - 3.5 Orders, payments, escrow & refunds  
  - 3.6 Notifications & communication  
  - 3.7 Content & miscellaneous  
  - 3.8 Example REST / RPC usage patterns  
- **4. Views**
- **5. Row Level Security (RLS) & Policies**
  - 5.1 How RLS works in Supabase  
  - 5.2 RLS flags (per table)  
  - 5.3 Example policies and patterns  
- **6. Functions (Database-Level, Potential RPCs)**
  - 6.1 Auth helper functions  
  - 6.2 Extension functions (crypto, net, vault)  
  - 6.3 Designing and using custom RPC functions  
- **7. Extensions & Platform Features**
- **8. Supabase APIs and How to Call Them**
  - 8.1 REST (PostgREST)  
  - 8.2 RPC (database functions)  
  - 8.3 GraphQL  
  - 8.4 Realtime  
- **9. Operational Notes & Maintenance**
  - 9.1 Regenerating this documentation  
  - 9.2 Checking schema/permissions via SQL  
  - 9.3 CLI commands (without Docker)  

---

## 1. Schemas – High-Level Overview

The snapshot reports the following active schemas:

- **`auth`**  
  Supabase-managed authentication schema. Contains identities, sessions, MFA, OAuth, and audit tables.  
  You normally **do not write into this schema directly** from the app; it is driven by Supabase Auth.

- **`public`**  
  Main **application schema**. Almost all business data for SaralEvents lives here: users, vendors, services, bookings, events, payments, refunds, notifications, etc.  
  This is the schema your frontend and backend talk to via Supabase REST/RPC/GraphQL.

- **`graphql` / `graphql_public`**  
  Schemas used by the `pg_graphql` extension to expose a GraphQL API over the database.

- **`extensions`**  
  Internal objects (views, functions, etc.) created by installed Postgres extensions such as `pg_stat_statements`, `pgcrypto`, and `uuid-ossp`.

- **`net`**  
  Schema used by the `pg_net` extension for HTTP/cron style jobs and request queues.

- **`vault`**  
  Schema used by the `supabase_vault` extension for encrypted secrets and secure access patterns.

- **`realtime`**  
  Internal schema that powers Supabase Realtime (logical replication and realtime notifications).

---

## 2. Tables in the `auth` Schema

### 2.1 Purpose and responsibilities

The `auth` schema is **fully managed by Supabase** and holds all data related to:

- Users and their identities.
- Sessions and tokens.
- Multi-factor authentication.
- OAuth applications and authorizations.
- Auth audit logs and internal state.

RLS is enabled on key tables by default and policies are defined by Supabase to ensure users can only see their own sensitive data.

### 2.2 Key tables and typical usage

Representative tables (not exhaustive):

- **`auth.audit_log_entries`**  
  - Records security/audit events for auth operations (logins, password changes, etc.).  
  - Useful if you need to investigate suspicious auth activity.

- **`auth.flow_state`**  
  - Tracks ongoing auth flows (e.g. password reset, email confirmation).  
  - Mostly internal, you read this only for deep debugging.

- **`auth.identities`**  
  - Links a logical Supabase user to identity providers (email, phone, OAuth providers like Google, GitHub, etc.).  
  - You normally access user info via Supabase client libraries instead of hitting this table directly.

- **`auth.instances`**  
  - Bookkeeping for Supabase instances; internal to the platform.

- **`auth.mfa_amr_claims`**, **`auth.mfa_challenges`**, **`auth.mfa_factors`**  
  - All MFA state: factors registered for a user, active challenges, and AMR (Authentication Method Reference) data.  
  - Only relevant if your app is using multi-factor auth features.

- **`auth.oauth_authorizations`**, **`auth.oauth_client_states`**, **`auth.oauth_clients`**, **`auth.oauth_consents`**  
  - Manage OAuth clients and authorization codes/consents.  
  - You do not normally write into these tables — instead you configure OAuth in Supabase dashboard, and the platform populates them.

### 2.3 Example queries and API calls

In most cases, you should use **Supabase client SDKs** to interact with auth, but for debugging you may run queries like:

- **List recent auth audit entries (debug only)**:

```sql
select *
from auth.audit_log_entries
order by created_at desc
limit 50;
```

- **See identities for a specific user**:

```sql
select *
from auth.identities
where user_id = '00000000-0000-0000-0000-000000000000';
```

> **Usage note**: Application code should **rarely query these directly**. Instead rely on Supabase client libraries and the `auth` schema helper functions (e.g. `auth.uid()` in policies).

---

## 3. Tables in the `public` Schema (Application Domain)

The `public` schema is where your SaralEvents business logic lives. This section groups tables by functional area and explains how they relate to each other.

### 3.1 User & Role Management

- **`public.profiles` / `public.user_profiles`**  
  - Store user-specific profile data such as names, contact details, and possibly app-level settings.  
  - Typically linked to the `auth.users` table via a `user_id` (UUID) foreign key.  
  - Frontend commonly:
    - Inserts a row here when a new user signs up.
    - Reads this table for showing profile screens.

- **`public.user_roles`**  
  - Defines roles for users (e.g. `admin`, `vendor`, `customer`).  
  - You can:
    - Use this in RLS policies (e.g. only `admin` can read all users).  
    - Join it with `user_profiles` or `profiles` in custom views or RPCs.

- **`public.admin_users`**  
  - Explicit list of admin-level users.  
  - RLS policies ensure only authenticated users can see/insert/update, and you may further restrict to “real admins” in your policies or via role checks.  
  - Often used in backend logic to give extra permissions or to drive admin dashboards.

### 3.2 Vendors & Services

- **`public.services`**  
  - Core service offerings (e.g. catering, decor, photography).  
  - Usually has foreign keys to:
    - `vendor_profiles` (or similar vendor table)  
    - `categories`  
  - Frontend uses this for:
    - Listing services on search pages.  
    - Attaching services to bookings.

- **`public.service_availability`**  
  - Time/slot availability for specific services – used to check if a service can be booked for a given date/time.  
  - Common query:

```sql
select *
from public.service_availability
where service_id = :service_id
  and available_from <= :desired_start
  and available_to >= :desired_end;
```

- **`public.service_reviews`**  
  - Reviews/ratings associated with services by users/customers.  
  - Typically linked to:
    - `services` (service being reviewed)  
    - `user_profiles` or `profiles` (review author)

- **Category-specific “service type” tables**:
  - `public.allServicesFull` – Combined “all services” dataset; central table/view used by several queries and views.  
  - `public.cateringServices`  
  - `public.decorServices`  
  - `public.eventEssentials`  
  - `public.farmhouseServices`  
  - `public.musicDjServices`  
  - `public.photographyServices`  

  These typically:

  - Provide extra fields specific to that service type (e.g. `food_type` for catering, `seating_capacity` for venues).  
  - Are joined back into `allServicesFull` and vendor-related views like `vendor_services_view`.

### 3.3 Events & Bookings

- **`public.events`**  
  - Represents an event (wedding, party, etc.) in the system.  
  - Typically has fields like:
    - `id`, `owner_user_id`, `name`, `date`, `location`, `status`.  
  - Core table for almost every user workflow.

- **`public.event_timeline`**  
  - Timeline details for events (milestones, scheduled items, tasks with times).  
  - Commonly queried together with `events` to build a full event schedule.

- **`public.event_activity_log`**  
  - Log of user and system activities related to events (status changes, updates, assignments).  
  - Good for audits and debugging user issues.

- **`public.event_notes`**  
  - Free-form notes related to events (internal comments, vendor notes, etc.).

- **`public.event_statistics`**  
  - Aggregated metrics and stats per event (e.g. total spend, number of guests, number of bookings).  
  - Useful for analytics dashboards.

- **`public.bookings`**  
  - Core booking records linking customers, events, and services (date/time, status, amount, etc.).  
  - Likely includes foreign keys to:
    - `events`  
    - `services`  
    - `user_profiles` / `profiles` (customer)

- **`public.booking_drafts`**  
  - In-progress bookings not yet confirmed. Useful for multi-step booking flows, e.g. “draft cart / quote” workflows.

- **`public.booking_status_updates`**  
  - History of status changes for bookings (e.g. `pending → confirmed → completed → cancelled`).  
  - Allows you to reconstruct how and when a booking changed over time.

### 3.4 Guests, Invitations & Checklists

- **`public.guest_categories`**  
  - Categories/segments of guests (e.g. family, friends, colleagues).  
  - Used to group guests for planning and seating.

- **`public.guests`**  
  - Individual guests associated with an event, including contact information and RSVP status.  
  - Typically linked to:
    - `events` (which event this guest belongs to)  
    - `guest_categories`

- **`public.invitations`**  
  - Invitations issued for events, which may include:
    - Channel (email, SMS, link).  
    - Unique tokens.  
    - Expiration or metadata.

- **`public.invitation_rsvps`**  
  - RSVP responses to invitations (accept/decline, guest count, notes).  
  - Usually linked to:
    - `invitations`  
    - `guests` (if RSVP is per guest)

- **`public.checklist_tasks`**  
  - Event planning tasks (e.g. “book venue”, “confirm catering”).  
  - Linked to events and optionally to users (assignees).  
  - Good candidate for task/todo interfaces.

### 3.5 Orders, Payments, Escrow & Refunds

- **`public.orders`**  
  - Commercial orders placed in the system, typically tied to bookings or services.  
  - Likely includes `user_id`, `booking_id`, `status`, totals, etc.

- **`public.order_items`**  
  - Line items within an order (service items, quantities, prices).  
  - Enables itemized invoices and summaries.

- **`public.order_notifications`**  
  - Notification records related to orders (e.g. payment reminders, confirmation).  
  - Ties together orders with the notifications subsystem.

- **`public.payment_orders`**  
  - Payment-level records, often mapping to external payment gateway references (e.g. Razorpay, Stripe).  
  - Good place to store gateway IDs, statuses, and metadata.

- **`public.payment_milestones`**  
  - Milestone-based payments for bookings (deposits, stage payments, final settlement).  
  - Gives you fine-grained control over when and how money moves.

- **`public.escrow_transactions`**  
  - Records transfers to/from escrow.  
  - Critical for tracking funds that are held until event completion or policy conditions are met.

- **`public.refunds`**  
  - Refund records for orders/bookings.  
  - Tightly tied to RLS and business rules to prevent abuse.  
  - Often referenced in admin tools and automated flows.

- **`public.refund_milestones`**  
  - Milestone-based details around refunds, mapping to cancellation policies and partial refund scenarios.  
  - Example: partial refund if cancellation happens close to event date.

- **`public.saved_billing_details`**  
  - Saved billing/contact information for re-use across orders/payments.  
  - Useful for one-click checkouts or recurring customers.

### 3.6 Notifications & Communication

- **`public.notifications`**  
  - Individual notifications generated by the system (push, in-app, email).  
  - Likely includes fields for type, content, read/unread status, and target user.

- **`public.notification_campaigns`**  
  - Higher-level campaigns for bulk or automated notifications (e.g. “Event reminder 7 days before”).

- **`public.fcm_tokens`**  
  - Device tokens for push notifications (Firebase Cloud Messaging).  
  - Typically stores `user_id` and token details.

- **`public.support_tickets`**  
  - User-submitted support queries and workflow tracking (status, priority, assigned support agent, etc.).

### 3.7 Content & Miscellaneous

- **`public.app_assets`**  
  - Metadata for app assets (images, documents, etc.).  
  - Often includes a reference to Supabase Storage bucket/paths.

- **`public.categories`**  
  - Service or event categories used for filtering and discovery.

- **`public.budget_items`**  
  - Per-event or per-booking budget entries for planning and cost breakdown.

- **`public.faqs`**  
  - Frequently asked questions or help articles for end-users.

### 3.8 Example REST / RPC Usage Patterns

Below are concrete examples of how to interact with `public` schema tables through Supabase.

- **Fetch bookings for the current authenticated user (REST)**:

```http
GET /rest/v1/bookings?user_id=eq.{{ current_user_id }} HTTP/1.1
apikey: <service_role_or_anon_key>
Authorization: Bearer <jwt_from_supabase>
```

RLS should typically ensure that a user can only see their own bookings, even if they try to change the filter.

- **Insert a new booking draft (REST)**:

```http
POST /rest/v1/booking_drafts HTTP/1.1
apikey: <service_role_or_anon_key>
Authorization: Bearer <jwt_from_supabase>
Content-Type: application/json

{
  "event_id": "<event-uuid>",
  "service_id": "<service-uuid>",
  "status": "draft",
  "notes": "Initial draft from mobile app"
}
```

- **Call a custom RPC function (example) to finalize booking**:

```http
POST /rest/v1/rpc/finalize_booking HTTP/1.1
apikey: <service_role_or_anon_key>
Authorization: Bearer <jwt_from_supabase>
Content-Type: application/json

{
  "draft_id": "<booking-draft-uuid>"
}
```

The `finalize_booking` function (defined by you) would:

- Validate the draft.  
- Create a `bookings` record.  
- Possibly create payment milestones and notifications.

---

## 4. Detailed Structural Reference (Columns, Keys, Indexes)

The CSV/JSON snapshot you provided also contains **every column**, **primary key**, **foreign key**, and **index** definition.  
This section explains how that information is structured and how to re-check it at any time from Supabase SQL editor.

### 4.1 Columns

In the snapshot, each entry under `"columns"` has:

- `schema` – e.g. `public`, `auth`.  
- `table` – table name, e.g. `bookings`.  
- `column` – column name.  
- `data_type` – Postgres data type (e.g. `uuid`, `text`, `timestamp with time zone`, `integer`, `numeric`).  
- `is_nullable` – `"YES"` / `"NO"`.  
- `column_default` – default expression (e.g. `now()`, `uuid_generate_v4()`, or `null`).  
- `ordinal` – position of the column.

To see full column details for any table directly in the SQL editor:

```sql
select column_name,
       data_type,
       is_nullable,
       column_default
from information_schema.columns
where table_schema = 'public'
  and table_name   = 'bookings'
order by ordinal_position;
```

You can change `table_name` to any table (e.g. `refunds`, `services`) to see “everything” for that table’s columns.

### 4.2 Primary keys

The `"primary_keys"` section of the snapshot has, for each primary key column:

- `schema` – schema name.  
- `table` – table name.  
- `column` – column that is part of the primary key.  
- `constraint_name` – the primary key constraint (e.g. `bookings_pkey`).

To inspect primary keys live:

```sql
select kcu.table_schema,
       kcu.table_name,
       tco.constraint_name,
       kcu.column_name
from information_schema.table_constraints tco
join information_schema.key_column_usage kcu
  on kcu.constraint_name = tco.constraint_name
 and kcu.constraint_schema = tco.constraint_schema
where tco.constraint_type = 'PRIMARY KEY'
  and kcu.table_schema = 'public'
order by kcu.table_schema, kcu.table_name, tco.constraint_name, kcu.ordinal_position;
```

This query recreates the `"primary_keys"` information from your snapshot.

### 4.3 Foreign keys (relations between tables)

The `"foreign_keys"` section of the snapshot lists, for each relation:

- `schema` / `table` / `column` – where the foreign key lives.  
- `ref_schema` / `ref_table` / `ref_column` – the referenced table/column.  
- `constraint_name` – the FK constraint name (e.g. `bookings_event_id_fkey`).

For example, the snapshot shows:

- `public.allServicesFull.vendor_id` → `public.vendor_profiles.id`  
- `public.booking_drafts.service_id` → `public.services.id`

To see all foreign keys in `public` from the database:

```sql
select tc.table_schema,
       tc.table_name,
       kcu.column_name,
       ccu.table_schema as ref_schema,
       ccu.table_name   as ref_table,
       ccu.column_name  as ref_column,
       tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.table_schema    = kcu.table_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
 and ccu.constraint_schema = tc.table_schema
where tc.constraint_type = 'FOREIGN KEY'
  and tc.table_schema = 'public'
order by tc.table_schema, tc.table_name, tc.constraint_name, kcu.column_name;
```

This represents **all relationships** in your database (the same information your CSV contains under `"foreign_keys"`).

### 4.4 Indexes

The `"indexes"` section in the snapshot includes:

- `schema` – schema name.  
- `table` – table name.  
- `index_name` – name of the index.  
- `definition` – full `CREATE INDEX ...` statement.

Example entries from the snapshot:

- `auth.audit_log_entries_pkey` – primary key index on `auth.audit_log_entries(id)`.  
- `auth.audit_logs_instance_id_idx` – index on `auth.audit_log_entries(instance_id)`.  
- Many more for `flow_state`, `bookings`, `orders`, etc.

To see indexes directly:

```sql
select schemaname as schema,
       tablename  as table,
       indexname,
       indexdef as definition
from pg_indexes
where schemaname = 'public'
order by schemaname, tablename, indexname;
```

This matches the `"indexes"` array in your CSV.

### 4.5 Views and Materialized Views

From the snapshot:

- `"views"` – lists:
  - `schema`  
  - `name`  
  - `definition` (SQL text for the view).
- `"materialized_views"` – exists but is **empty** in your snapshot:

```json
"materialized_views": []
```

That means **you currently do not have any materialized views** defined in this project at the time of the snapshot.

To list views from the DB:

```sql
select table_schema as schema,
       table_name   as name,
       view_definition
from information_schema.views
where table_schema not in ('pg_catalog', 'information_schema')
order by table_schema, table_name;
```

To list materialized views (if you add some in future):

```sql
select n.nspname as schema,
       c.relname as name,
       pg_get_viewdef(c.oid) as definition
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'm'
  and n.nspname not in ('pg_catalog', 'information_schema');
```

These queries cover **all structural pieces** present in your original CSV snapshot.

---

## 5. Views

The snapshot reports the following important views:

- **`extensions.pg_stat_statements`** and **`extensions.pg_stat_statements_info`**  
  - Provided by the `pg_stat_statements` extension.  
  - Allow inspection of query performance (calls, timings, I/O, etc.).  
  - Useful for DB performance debugging; not typically used by application code.

- **`public.vendor_bookings_view`**  
  - Definition joins:
    - `bookings` (bookings)
    - `services` (service metadata)
    - `user_profiles` (customer identity)
  - Exposes fields like booking ID, booking date/time, status, amount, notes, service name, and customer contact details.  
  - Has a `WHERE (s.vendor_id = auth.uid())` filter, ensuring **vendors only see bookings related to their own services**.  
  - Intended as a **read-optimized vendor dashboard view**.

- **`public.vendor_services_view`**  
  - Definition joins:
    - `vendor_profiles` (`vp`)
    - `allServicesFull` (`asf`) via vendor_id and category/service_type.  
  - Exposes which services belong to which vendor, with business name and categories.  
  - Used by vendor-facing UI to list their services and types.

- **`vault.decrypted_secrets`**  
  - A view provided by the `supabase_vault` extension.  
  - Allows controlled access to decrypted secrets.  
  - Actual usage is via extension functions and strict RLS, not direct application-wide querying.

> **Note**: Views are available via Supabase REST just like tables (e.g. `/rest/v1/vendor_bookings_view`) but always respect underlying RLS and policies.

---

## 6. Row Level Security (RLS) & Policies

### 6.1 How RLS works in Supabase

- RLS is a **Postgres feature** that filters rows per query based on policies.  
- Supabase **always enforces RLS** for non-service-role keys.  
- You attach RLS policies to tables, and each policy:
  - Targets one or more commands: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `ALL`.  
  - Specifies which **roles** it applies to.  
  - Provides `USING` and `WITH CHECK` expressions that must evaluate to `true`.

Some helper functions from the `auth` schema:

- `auth.uid()` – returns the UUID of the currently authenticated user (from JWT).  
- `auth.role()` – returns the database role (`anon`, `authenticated`, etc.).

### 6.2 RLS Flags

From the `rls_tables` section:

- Many **`auth`** tables (e.g. `audit_log_entries`, `flow_state`, `identities`, `instances`, `mfa_*`) have:  
  - `rls_enabled: true`  
  - `rls_forced: false` (RLS is on but not forcibly applied in all contexts – standard Supabase defaults).

- Many **`public`** tables also have RLS entries, meaning that access is controlled through policies rather than just roles.

### 6.3 Example RLS Policies

From the `rls_policies` section:

- **Table: `public.admin_users`**
  - Policy: **“Authenticated users can insert admin_users”** (`INSERT`)  
    - `roles: ["public"]` (Supabase “public” database role, backing authenticated/anonymous roles).  
    - `check_expression: (auth.uid() IS NOT NULL)`  
    - Only **authenticated users** can insert admin_users records.
  - Policy: **“Authenticated users can update admin_users”** (`UPDATE`)  
    - `using_expression: (auth.uid() IS NOT NULL)`  
  - Policy: **“Authenticated users can view admin_users”** (`SELECT`)  
    - `using_expression: (auth.uid() IS NOT NULL)`  
  - **Net effect**: Unauthenticated callers see nothing; authenticated users can read and write admin user data (you may still add additional checks for “real admins” in app logic or extra RLS).

- **Open “ALL” policies**
  - For some public tables, such as:
    - `public.allServicesFull`  
    - `public.app_assets`  
    - `public.booking_drafts` (policy named `ALL`)  
    - and others…  
  - Policies are of the form:
    - `command: "ALL"`  
    - `permissive: "PERMISSIVE"`  
    - `check_expression: "true"`  
    - `using_expression: "true"`  
  - **Net effect**: For those tables, RLS is technically enabled, but the policies allow all roles (often including unauthenticated) to read and write everything.  
  - This is appropriate for truly public data but must be regularly reviewed for security-sensitive tables.

> **Recommendation**: For critical tables (payments, refunds, admin settings), avoid blanket `"ALL"` policies and prefer tightly scoped, role-based policies using `auth.uid()` and `auth.role()`.

#### 6.3.1 Example secure policy pattern

Example of a more restrictive policy for `public.bookings`:

```sql
create policy "Users can see their own bookings"
on public.bookings
for select
using (user_id = auth.uid());
```

Similarly, for vendors:

```sql
create policy "Vendors see bookings for their services"
on public.bookings
for select
using (exists (
  select 1
  from public.services s
  where s.id = bookings.service_id
    and s.vendor_id = auth.uid()
));
```

These patterns mirror what your `vendor_bookings_view` is already doing via a `WHERE s.vendor_id = auth.uid()` filter.

---

## 7. Functions (Database-Level, Potential RPCs)

The `functions` section of the snapshot contains:

- **Auth helper functions (schema `auth`)** – e.g.:
  - `auth.email()`  
  - `auth.jwt()`  
  - `auth.role()`  
  - `auth.uid()`  
  - Language: `sql`, Volatility: `stable` (`s`)  
  - Used in queries and RLS expressions to fetch the current user, role, etc.  
  - Example: `auth.uid()` appears in policies such as `using_expression: (auth.uid() IS NOT NULL)`.

- **Extension functions (schema `extensions`)** – e.g.:
  - `armor`, `dearmor`, `crypt`, `decrypt`, `decrypt_iv`, and many others.  
  - Language: `c`, Volatility: usually `immutable` (`i`) for crypto/encoding.  
  - Provided by `pgcrypto`, `pg_net`, etc., and used anywhere secure hashing, encryption, or external calls are needed.

- **Usage as Supabase RPC**:
  - Any secure, app-level function you define in `public` (or other application schema) can be exposed as an RPC endpoint via Supabase:  
    - Endpoint: `/rest/v1/rpc/<function_name>`  
  - RPC functions should be carefully written to respect RLS and roles (they run with caller’s privileges unless you explicitly mark them as `SECURITY DEFINER`).

> **Note**: This snapshot lists only database-side functions. Supabase Edge Functions are managed separately via the Supabase CLI and are **not** visible in this SQL-based introspection.

### 7.3 Designing and using custom RPC functions

When you create your own SQL or `plpgsql` functions, you can:

- Place them in `public` (or another app schema).  
- Optionally expose them as RPC endpoints via Supabase.

General guidelines:

- **Keep them small and focused** – one clear responsibility per function.  
- **Respect RLS** – functions run with the caller’s role by default, so `auth.uid()` still works and existing policies still apply.  
- **Use them to encapsulate complex flows** – e.g. booking finalization, refund workflows, multi-step writes.

Example: A simplified RPC to issue a refund for an order:

```sql
create or replace function public.issue_refund(p_order_id uuid, p_reason text)
returns void
language plpgsql
as $$
begin
  -- Insert into refunds table
  insert into public.refunds (order_id, reason, created_by)
  values (p_order_id, p_reason, auth.uid());

  -- Optionally insert refund milestones, notifications, etc.
end;
$$;
```

Once exposed as RPC in Supabase, you call it via:

```http
POST /rest/v1/rpc/issue_refund HTTP/1.1
apikey: <service_role_or_anon_key>
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "p_order_id": "<order-uuid>",
  "p_reason": "Customer cancelled due to weather"
}
```

---

## 8. Extensions & Platform Features

From the `extensions` array in the snapshot:

- **`pg_graphql` (schema `graphql`, version `1.5.11`)**  
  - Provides a GraphQL API over your Postgres schema.  
  - Respects existing RLS and policies.

- **`pg_net` (schema `public`, version `0.14.0`)**  
  - Allows the database to perform HTTP requests and asynchronous jobs.  
  - Often used for webhooks or calling external APIs from triggers or background jobs.

- **`pg_stat_statements` (schema `extensions`, version `1.11`)**  
  - Collects execution statistics of all SQL statements.  
  - Used by `pg_stat_statements` views for performance monitoring.

- **`pgcrypto` (schema `extensions`, version `1.3`)**  
  - Provides cryptographic functions and utilities (hashing, encryption, digests).  
  - Often used for secure token generation, password hashing, etc.

- **`uuid-ossp` (schema `extensions`, version `1.1`)**  
  - Provides functions to generate UUIDs (v1, v4, etc.).  
  - Commonly used for `uuid` primary keys.

- **`supabase_vault` (schema `vault`, version `0.3.1`)**  
  - Secrets management extension.  
  - Integrates with the `vault` schema and `decrypted_secrets` view for controlled secret decryption.

- **`plpgsql` (schema `pg_catalog`, version `1.0`)**  
  - Procedural language for writing functions and triggers in Postgres.  
  - Enabled by default and required for many internal functions.

---

## 9. Supabase APIs and How to Call Them

- **REST API (PostgREST)**  
  - Each table and view in `public` (and other exposed schemas) is available as `/rest/v1/<table_or_view>`.  
  - RLS and policies described above are always enforced.

- **RPC (Database functions)**  
  - Functions exposed in Supabase appear under `/rest/v1/rpc/<function_name>`.  
  - They can encapsulate complex logic, but still respect RLS/policies unless marked otherwise.

- **GraphQL**  
  - With `pg_graphql` enabled, your schema is also available via a GraphQL endpoint.  
  - The shape of the GraphQL schema mirrors the underlying tables/views and enforces the same RLS.

- **Realtime**  
  - Tables in `public` (and optionally others) can emit realtime change events.  
  - Backed by the `realtime` schema and logical replication.

---

## 10. Operational Notes & Maintenance

### 10.1 Regenerating this document

- Re-run the introspection SQL in the Supabase SQL editor to obtain a fresh JSON snapshot.  
- Save the result (JSON or CSV) and update sections of this document when:
  - You add or remove tables/views.  
  - You significantly change RLS policies for critical tables (bookings, payments, refunds, admin users).

### 10.2 Checking schema/permissions via SQL

Useful queries to quickly inspect structure from the SQL editor:

- **List tables in `public`**:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
```

- **Check RLS status for a table**:

```sql
select relname as table,
       relrowsecurity as rls_enabled,
       relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'bookings';
```

- **List policies for a given table**:

```sql
select schemaname,
       tablename,
       policyname,
       cmd,
       roles,
       permissive,
       qual as using_expression,
       with_check as check_expression
from pg_policies
where schemaname = 'public'
  and tablename = 'bookings';
```

### 10.3 CLI commands (without Docker)

You can use Supabase CLI to get remote project information without running Docker:

- **Project description (linked project)**:

```powershell
npx supabase projects describe --linked -o json
```

- **Pull DB schema locally**:

```powershell
npx supabase db pull --linked
```

- **List edge functions**:

```powershell
npx supabase functions list --linked -o json
```

- **Generate TypeScript types for the DB**:

```powershell
npx supabase gen types typescript --linked > db_types.ts
```

These commands complement this document by giving you **live, up-to-date** metadata based on the real project state.

