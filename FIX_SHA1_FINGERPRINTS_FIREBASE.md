# Fix: Add SHA-1 Fingerprints to Firebase

## 🔍 **ISSUE**

You have **two SHA-1 certificate fingerprints** that need to be added to Firebase:
- `a4a61a184912972627b343b6cef5952e58870701`
- `cf1f5a62d65f8ee2addf9701fc7c0e0486e5b838`

These are required for:
- ✅ Google Sign-In to work
- ✅ FCM push notifications (sometimes)
- ✅ Firebase Authentication

---

## 🔧 **STEP-BY-STEP FIX**

### **Step 1: Add SHA-1 to User App**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **saralevents-6fe20**
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Find **Android app** with package name: `com.saralevents.userapp`
6. Click on it (or click the **settings icon** ⚙️)
7. Scroll to **SHA certificate fingerprints** section
8. Click **Add fingerprint**
9. Paste: `a4a61a184912972627b343b6cef5952e58870701`
10. Click **Save**
11. Click **Add fingerprint** again
12. Paste: `cf1f5a62d65f8ee2addf9701fc7c0e0486e5b838`
13. Click **Save**

**You should now see 2 SHA-1 fingerprints listed for the user app.**

### **Step 2: Add SHA-1 to Vendor App**

1. Still in Firebase Console > Project Settings
2. Find **Android app** with package name: `com.saralevents.vendorapp`
3. Click on it (or click the **settings icon** ⚙️)
4. Scroll to **SHA certificate fingerprints** section
5. Click **Add fingerprint**
6. Paste: `a4a61a184912972627b343b6cef5952e58870701`
7. Click **Save**
8. Click **Add fingerprint** again
9. Paste: `cf1f5a62d65f8ee2addf9701fc7c0e0486e5b838`
10. Click **Save**

**You should now see 2 SHA-1 fingerprints listed for the vendor app.**

### **Step 3: Download Updated google-services.json (Optional)**

**If Firebase asks you to download updated google-services.json:**

1. Click **Download google-services.json** button
2. **For User App:**
   - Replace: `apps/user_app/android/app/google-services.json`
3. **For Vendor App:**
   - Replace: `saral_events_vendor_app/android/app/google-services.json`

**Note:** Usually you don't need to re-download if the file already exists and has the correct package names.

---

## ✅ **VERIFICATION**

After adding SHA-1 fingerprints:

1. **Wait 1-2 minutes** for changes to propagate
2. **Test Google Sign-In** in both apps
3. **Test push notifications** again

---

## 🔍 **WHICH FINGERPRINT IS WHICH?**

**Common scenarios:**
- **First fingerprint** (`a4a61a...`) - Usually **Debug keystore**
- **Second fingerprint** (`cf1f5a...`) - Usually **Release keystore** or **Different debug keystore**

**To verify which is which:**

**Get Debug SHA-1:**
```powershell
cd apps/user_app/android
.\gradlew signingReport
```

**Or:**
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Look for the SHA1 value** - it should match one of your fingerprints.

---

## 📝 **NOTES**

- ✅ Both fingerprints should be added to **both apps** (user and vendor)
- ✅ This is required for Google Sign-In to work properly
- ✅ May help with FCM token registration
- ✅ Changes take 1-2 minutes to propagate

---

**After adding fingerprints, test notifications again!**
