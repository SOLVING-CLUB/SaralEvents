# Vendor FCM Token - Instructions

## ❌ **CURRENT STATUS**

**Vendor has NO active FCM token:**
- Vendor: Sun City Farmhouse
- Vendor user_id: `777e7e48-388c-420e-89b9-85693197e0b7`
- Status: ❌ No active token

**This means:**
- ❌ Vendor will NOT receive push notifications
- ❌ Notifications will fail silently
- ✅ Function works, but no token to send to

---

## ✅ **SOLUTION**

### **Option 1: Vendor Registers Token via App (Recommended)**

**Vendor needs to:**
1. Open vendor app
2. Log in with their account
3. App should automatically register FCM token

**Check if token was registered:**
```sql
SELECT * FROM fcm_tokens
WHERE user_id = '777e7e48-388c-420e-89b9-85693197e0b7'
  AND app_type = 'vendor_app'
  AND is_active = true;
```

### **Option 2: Check Vendor App Code**

**Verify vendor app has FCM token registration:**
- Check if `FirebaseMessaging.instance.getToken()` is called
- Check if token is saved to `fcm_tokens` table
- Check if `app_type` is set to `'vendor_app'`

### **Option 3: Manual Token Registration (For Testing)**

**If you have the FCM token from vendor app:**
```sql
INSERT INTO fcm_tokens (user_id, token, app_type, is_active, created_at, updated_at)
VALUES (
  '777e7e48-388c-420e-89b9-85693197e0b7'::UUID,
  '<fcm_token_from_vendor_app>',
  'vendor_app',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (user_id, app_type) 
DO UPDATE SET 
  token = EXCLUDED.token,
  is_active = true,
  updated_at = NOW();
```

---

## 🔍 **CHECK TOKEN STATUS**

**Run:** `CHECK_VENDOR_FCM_TOKEN.sql`

**This will show:**
1. All FCM tokens for the vendor
2. Token summary (active/inactive)
3. Vendor profile
4. Test notification (will show if function works)

---

## 📋 **NEXT STEPS**

1. **Have vendor log in** to vendor app
2. **Check fcm_tokens table** - Is token registered?
3. **If token registered** → Test notifications
4. **If no token** → Check vendor app code for FCM registration

---

## ✅ **ONCE TOKEN IS REGISTERED**

**Then you can:**
1. Test vendor notifications
2. Update booking status
3. Vendor will receive notifications

---

**Check token status and have vendor log in to register token!**
