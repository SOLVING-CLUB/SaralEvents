# Register Vendor FCM Token

## ❌ **PROBLEM**

**Vendor has NO active FCM token:**
- Vendor user_id: `777e7e48-388c-420e-89b9-85693197e0b7`
- Business: Sun City Farmhouse
- Status: ❌ No active token - notification will fail

---

## ✅ **SOLUTION: Register FCM Token**

**The vendor needs to register their FCM token in the vendor app.**

### **How FCM Token Registration Works:**

1. **Vendor opens vendor app**
2. **Vendor logs in**
3. **App automatically registers FCM token** (if implemented correctly)
4. **Token is saved to `fcm_tokens` table**

---

## 🔍 **CHECK IF TOKEN REGISTRATION IS IMPLEMENTED**

### **Check Vendor App Code:**

Look for FCM token registration in your vendor app code. It should:
1. Get FCM token from Firebase
2. Save it to `fcm_tokens` table with:
   - `user_id` = vendor's user_id
   - `app_type` = 'vendor_app'
   - `is_active` = true

### **Example Code (Flutter):**

```dart
// In vendor app, after login
Future<void> registerFCMToken() async {
  // Get FCM token
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  
  if (fcmToken != null) {
    // Get current user
    final user = supabase.auth.currentUser;
    
    if (user != null) {
      // Save to fcm_tokens table
      await supabase.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': fcmToken,
        'app_type': 'vendor_app',
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
```

---

## 🧪 **TEST: Register Token Manually**

**If token registration isn't working, you can test by manually inserting a token:**

1. **Get FCM token from vendor app:**
   - Vendor opens app
   - Check app logs for FCM token
   - Or use Firebase Console to get token

2. **Insert token manually:**
```sql
-- Replace <fcm_token> with actual token from vendor app
INSERT INTO fcm_tokens (user_id, token, app_type, is_active, created_at, updated_at)
VALUES (
  '777e7e48-388c-420e-89b9-85693197e0b7'::UUID,
  '<fcm_token>',
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

## 🔍 **CHECK TOKEN REGISTRATION**

**After vendor logs in to vendor app, check:**

```sql
SELECT 
  user_id,
  app_type,
  is_active,
  created_at,
  updated_at
FROM fcm_tokens
WHERE user_id = '777e7e48-388c-420e-89b9-85693197e0b7'
  AND app_type = 'vendor_app'
ORDER BY updated_at DESC;
```

---

## ✅ **ONCE TOKEN IS REGISTERED**

**Then test vendor notifications:**

1. **Run:** `TEST_VENDOR_NOTIFICATION_FIXED.sql`
2. **Check vendor app** for notifications
3. **Update booking status** to trigger notification

---

## 📋 **NEXT STEPS**

1. **Check vendor app code** - Is FCM token registration implemented?
2. **Have vendor log in** to vendor app
3. **Check fcm_tokens table** - Is token registered?
4. **Test notifications** once token is registered

---

**Once vendor has active FCM token, notifications will work!**
