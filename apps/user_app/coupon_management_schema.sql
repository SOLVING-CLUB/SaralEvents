SELECT 1;
/*
  Coupon Management System Schema
  Supports: coupon codes, time frames, min order value, conditions, first-order-only,
  and phone-number whitelist for first-order discounts.
  Run this in Supabase SQL Editor.
*/

-- 1. Coupons table
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value DECIMAL(10, 2) NOT NULL CHECK (discount_value > 0),
  min_order_value DECIMAL(10, 2) DEFAULT 0 CHECK (min_order_value >= 0),
  max_discount_amount DECIMAL(10, 2), -- cap for percentage coupons (nullable = no cap)
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_until TIMESTAMPTZ, -- NULL = no end date
  usage_limit INTEGER, -- NULL = unlimited
  times_used INTEGER NOT NULL DEFAULT 0,
  first_order_only BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  -- Optional conditions: restrict to categories or service IDs (JSONB)
  -- e.g. {"categories": ["catering","decoration"], "service_ids": ["uuid1","uuid2"]}
  conditions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(LOWER(TRIM(code)));
CREATE INDEX IF NOT EXISTS idx_coupons_is_active ON coupons(is_active);
CREATE INDEX IF NOT EXISTS idx_coupons_valid_dates ON coupons(valid_from, valid_until);

-- ------------------------------------------------------------------
-- 2. Phone whitelist: apply a coupon's discount on first order for these phones
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupon_phone_whitelist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  phone_number TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(coupon_id, phone_number)
);

CREATE INDEX IF NOT EXISTS idx_coupon_phone_whitelist_coupon ON coupon_phone_whitelist(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_phone_whitelist_phone ON coupon_phone_whitelist(TRIM(phone_number));

-- ------------------------------------------------------------------
-- 3. Redemptions: who used which coupon on which booking (for limits & first-order)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  phone_number TEXT, -- if applied via phone whitelist
  discount_amount DECIMAL(10, 2) NOT NULL,
  redeemed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_coupon ON coupon_redemptions(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_user ON coupon_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_booking ON coupon_redemptions(booking_id);

-- ------------------------------------------------------------------
-- 4. Add coupon columns to bookings
-- ------------------------------------------------------------------
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS coupon_id UUID REFERENCES coupons(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2) DEFAULT 0 CHECK (discount_amount >= 0);

CREATE INDEX IF NOT EXISTS idx_bookings_coupon_id ON bookings(coupon_id);

-- ------------------------------------------------------------------
-- 5. RPC: Validate coupon and return discount (for user app checkout)
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_coupon(
  p_code TEXT,
  p_user_id UUID,
  p_phone TEXT,
  p_order_total_rs DECIMAL,
  p_service_ids UUID[] DEFAULT NULL -- optional: for category/service restrictions
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coupon coupons%ROWTYPE;
  v_discount DECIMAL(10, 2);
  v_user_has_ordered BOOLEAN;
  v_phone_whitelisted BOOLEAN := FALSE;
  v_conditions JSONB;
  v_restrict_categories TEXT[];
  v_restrict_services UUID[];
  v_service_cat TEXT;
  v_ok BOOLEAN := FALSE;
BEGIN
  -- Normalize code
  p_code := TRIM(LOWER(NULLIF(p_code, '')));
  IF p_code IS NULL OR p_code = '' THEN
    RETURN jsonb_build_object('valid', FALSE, 'message', 'Invalid coupon code');
  END IF;

  -- Load coupon
  SELECT * INTO v_coupon
  FROM coupons
  WHERE LOWER(TRIM(code)) = p_code AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'message', 'Coupon not found or inactive');
  END IF;

  -- Time window
  IF v_coupon.valid_from > NOW() THEN
    RETURN jsonb_build_object('valid', FALSE, 'message', 'Coupon is not yet valid');
  END IF;
  IF v_coupon.valid_until IS NOT NULL AND v_coupon.valid_until < NOW() THEN
    RETURN jsonb_build_object('valid', FALSE, 'message', 'Coupon has expired');
  END IF;

  -- Usage limit
  IF v_coupon.usage_limit IS NOT NULL AND v_coupon.times_used >= v_coupon.usage_limit THEN
    RETURN jsonb_build_object('valid', FALSE, 'message', 'Coupon usage limit reached');
  END IF;

  -- Min order value
  IF p_order_total_rs < COALESCE(v_coupon.min_order_value, 0) THEN
    RETURN jsonb_build_object(
      'valid', FALSE,
      'message', 'Minimum order value for this coupon is ₹' || COALESCE(v_coupon.min_order_value, 0)::TEXT
    );
  END IF;

  -- First order only: check if user (or phone) has any completed/pending/confirmed booking
  IF v_coupon.first_order_only THEN
    SELECT EXISTS(
      SELECT 1 FROM bookings b
      WHERE b.user_id = p_user_id
        AND b.status IN ('pending', 'confirmed', 'completed')
    ) INTO v_user_has_ordered;

    IF v_user_has_ordered THEN
      -- Check if this phone is whitelisted for first-order discount (same coupon)
      SELECT EXISTS(
        SELECT 1 FROM coupon_phone_whitelist w
        WHERE w.coupon_id = v_coupon.id
          AND TRIM(w.phone_number) = TRIM(p_phone)
      ) INTO v_phone_whitelisted;

      IF NOT v_phone_whitelisted THEN
        RETURN jsonb_build_object('valid', FALSE, 'message', 'This coupon is valid for first order only');
      END IF;
    END IF;
  END IF;

  -- Optional: check if phone is in whitelist (even when first_order_only is false, whitelist can grant access)
  IF p_phone IS NOT NULL AND TRIM(p_phone) <> '' THEN
    SELECT EXISTS(
      SELECT 1 FROM coupon_phone_whitelist w
      WHERE w.coupon_id = v_coupon.id AND TRIM(w.phone_number) = TRIM(p_phone)
    ) INTO v_phone_whitelisted;
  END IF;

  -- Conditions: categories or service_ids (from JSONB: {"categories": ["catering"], "service_ids": ["uuid", ...]})
  v_conditions := COALESCE(v_coupon.conditions, '{}');
  SELECT COALESCE(array_agg(elem), ARRAY[]::TEXT[]) INTO v_restrict_categories
  FROM jsonb_array_elements_text(v_conditions->'categories') AS elem;
  SELECT COALESCE(array_agg(elem::uuid), ARRAY[]::UUID[]) INTO v_restrict_services
  FROM jsonb_array_elements_text(v_conditions->'service_ids') AS elem;

  IF array_length(v_restrict_categories, 1) > 0 OR array_length(v_restrict_services, 1) > 0 THEN
    IF p_service_ids IS NULL OR array_length(p_service_ids, 1) IS NULL OR array_length(p_service_ids, 1) = 0 THEN
      RETURN jsonb_build_object('valid', FALSE, 'message', 'Coupon has category or service restrictions');
    END IF;
    -- Check at least one service matches: in service_ids list or vendor category in categories list
    SELECT EXISTS(
      SELECT 1 FROM services s
      LEFT JOIN vendor_profiles vp ON vp.id = s.vendor_id
      WHERE s.id = ANY(p_service_ids)
        AND (
          (array_length(v_restrict_services, 1) > 0 AND s.id = ANY(v_restrict_services))
          OR (array_length(v_restrict_categories, 1) > 0 AND vp.category IS NOT NULL AND LOWER(TRIM(vp.category)) IN (SELECT LOWER(TRIM(x)) FROM unnest(v_restrict_categories) x))
        )
    ) INTO v_ok;
    IF NOT v_ok THEN
      RETURN jsonb_build_object('valid', FALSE, 'message', 'Coupon does not apply to selected services');
    END IF;
  END IF;

  -- Compute discount
  IF v_coupon.discount_type = 'fixed' THEN
    v_discount := LEAST(v_coupon.discount_value, p_order_total_rs);
  ELSE
    v_discount := (p_order_total_rs * v_coupon.discount_value / 100.0);
    IF v_coupon.max_discount_amount IS NOT NULL THEN
      v_discount := LEAST(v_discount, v_coupon.max_discount_amount);
    END IF;
  END IF;

  IF v_discount <= 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'message', 'No discount applicable');
  END IF;

  RETURN jsonb_build_object(
    'valid', TRUE,
    'coupon_id', v_coupon.id,
    'code', v_coupon.code,
    'discount_amount', v_discount,
    'message', 'Coupon applied successfully'
  );
END;
$$;

-- ------------------------------------------------------------------
-- 6. Record redemption and increment times_used (call after booking created)
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION record_coupon_redemption(
  p_coupon_id UUID,
  p_user_id UUID,
  p_booking_id UUID,
  p_phone TEXT,
  p_discount_amount DECIMAL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO coupon_redemptions (coupon_id, user_id, booking_id, phone_number, discount_amount)
  VALUES (p_coupon_id, p_user_id, p_booking_id, p_phone, p_discount_amount);

  UPDATE coupons
  SET times_used = times_used + 1, updated_at = NOW()
  WHERE id = p_coupon_id;
END;
$$;

-- ------------------------------------------------------------------
-- 7. RLS
-- ------------------------------------------------------------------
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_phone_whitelist ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;

-- Coupons: company web (authenticated admin) does full CRUD; user app uses validate_coupon RPC only.
DROP POLICY IF EXISTS "Allow read active coupons" ON coupons;
DROP POLICY IF EXISTS "Allow all for authenticated" ON coupons;
CREATE POLICY "Allow all for authenticated" ON coupons FOR ALL
  USING (auth.uid() IS NOT NULL);

-- Phone whitelist: only admins (we use authenticated + app-side admin check; or service role)
DROP POLICY IF EXISTS "Allow all coupon_phone_whitelist" ON coupon_phone_whitelist;
CREATE POLICY "Allow all coupon_phone_whitelist" ON coupon_phone_whitelist FOR ALL
  USING (auth.uid() IS NOT NULL);

-- Redemptions: users can insert their own (when checkout records); read for own user_id
DROP POLICY IF EXISTS "Users can read own redemptions" ON coupon_redemptions;
CREATE POLICY "Users can read own redemptions" ON coupon_redemptions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own redemption" ON coupon_redemptions;
CREATE POLICY "Users can insert own redemption" ON coupon_redemptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow all for coupon_redemptions admin" ON coupon_redemptions;
CREATE POLICY "Allow all for coupon_redemptions admin" ON coupon_redemptions FOR ALL
  USING (auth.uid() IS NOT NULL);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON coupons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON coupon_phone_whitelist TO authenticated;
GRANT SELECT, INSERT ON coupon_redemptions TO authenticated;
GRANT UPDATE ON coupons TO authenticated; -- for times_used via RPC only; RPC uses SECURITY DEFINER
GRANT EXECUTE ON FUNCTION validate_coupon(TEXT, UUID, TEXT, DECIMAL, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION record_coupon_redemption(UUID, UUID, UUID, TEXT, DECIMAL) TO authenticated;
