# Coupon Management System

This document describes the coupon system that controls discounts for user orders in the user app, managed from the company web app.

## Features

- **Coupon codes**: Create coupons with codes (e.g. `SAVE20`), percentage or fixed-amount discounts.
- **Time frames**: Set `valid_from` and `valid_until` for each coupon.
- **Conditions**:
  - **Min order value**: Minimum cart total (₹) required to apply the coupon.
  - **Max discount cap**: For percentage coupons, optional cap in ₹.
  - **Usage limit**: Optional total number of redemptions per coupon.
  - **First order only**: Restrict the coupon to a user’s first order only.
  - **Category / service restrictions**: Optional JSONB `conditions` (e.g. `{"categories": ["catering"], "service_ids": ["uuid", ...]}`) to restrict by vendor category or specific service IDs.
- **Phone whitelist**: Add phone numbers to a coupon so those numbers get the coupon’s discount on their first order (used with “First order only” coupons).

## Database (Supabase)

1. **Run the schema**  
   In the Supabase SQL Editor, run:
   `apps/user_app/coupon_management_schema.sql`

   This creates:
   - `coupons` – coupon definitions (code, type, value, min/max, dates, limits, first_order_only, conditions, etc.).
   - `coupon_phone_whitelist` – phone numbers that get a coupon’s discount on first order.
   - `coupon_redemptions` – who used which coupon on which booking (for limits and first-order logic).
   - `bookings.coupon_id` and `bookings.discount_amount` – link and amount per booking.
   - RPCs: `validate_coupon(...)` and `record_coupon_redemption(...)`.

2. **RPCs**
   - **`validate_coupon(p_code, p_user_id, p_phone, p_order_total_rs, p_service_ids)`**  
     Returns JSONB: `{ valid, message, coupon_id?, code?, discount_amount? }`.  
     Used by the user app at checkout to validate a code and get the discount amount.
   - **`record_coupon_redemption(p_coupon_id, p_user_id, p_booking_id, p_phone, p_discount_amount)`**  
     Records a redemption and increments `coupons.times_used`.  
     Called by the user app after creating the first booking that used the coupon.

## Company Web App

- **Route**: `/admin/dashboard/coupons`
- **Sidebar**: “Coupons” (TicketPercent icon)
- **Actions**:
  - List all coupons (code, status, discount, usage, first-order flag).
  - Create / edit coupon: code, description, discount type & value, min order, max discount, valid from/until, usage limit, first order only, active.
  - Expand a coupon to manage **phone whitelist**: add/remove phone numbers for first-order-only discount.

## User App

- **Checkout (cart)**:
  - “Have a coupon?” section: text field + Apply.
  - On success: shows “Coupon X applied (−₹Y)” and a Remove button.
  - Cart total and installment breakdown use **total after discount**.
- **Payment**:
  - Advance (20%) and gateway amount are based on **total after discount**.
  - When creating bookings, the **first** cart item’s booking gets:
    - `amount = item price − discount` (discount capped by that item’s price),
    - `coupon_id` and `discount_amount` set.
  - Remaining items are created at full price with no coupon.
  - After the first booking is created, `record_coupon_redemption` is called once with that booking and the discount applied to it.

## Flow Summary

1. Admin creates a coupon in company web (optionally adds phone numbers for first-order discount).
2. User adds items to cart, goes to checkout, optionally enters a coupon and taps Apply.
3. User app calls `validate_coupon` with code, user id, phone (from billing), order total, and service IDs; displays discount and total after discount.
4. User completes payment; user app creates bookings (first one with coupon + discount), then calls `record_coupon_redemption` for that first booking.

This keeps coupon logic and limits in the database and ensures the same rules apply whether the user applies a code or is whitelisted by phone for a first-order discount.
