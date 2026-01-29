# Location and Maps Configuration Issues - Analysis & Fixes

## 🔍 Issues Found

### 1. **Missing Google Maps API Key in AndroidManifest.xml** ⚠️ CRITICAL
   - **Location**: `android/app/src/main/AndroidManifest.xml`
   - **Problem**: Google Maps SDK requires API key meta-data tag, but it's missing
   - **Impact**: Maps won't load on Android devices

### 2. **Hardcoded API Keys** ⚠️ SECURITY RISK
   - **Location 1**: `lib/screens/map_location_picker.dart` line 39
   - **Location 2**: `ios/Runner/AppDelegate.swift` line 11
   - **Problem**: API keys are hardcoded in source code
   - **Impact**: Security risk, keys exposed in version control

### 3. **Duplicate AppDelegate Class in iOS** ⚠️ COMPILATION ERROR
   - **Location**: `ios/Runner/AppDelegate.swift`
   - **Problem**: Two `@objc class AppDelegate` definitions (lines 6-14 and 21-28)
   - **Impact**: iOS app won't compile

### 4. **Commented Out manifestPlaceholders** ⚠️
   - **Location**: `android/app/build.gradle.kts` line 44
   - **Problem**: Google Maps API key placeholder is commented out
   - **Impact**: Can't use environment variables for API key

### 5. **Google Places SDK API Key** ⚠️
   - **Location**: `lib/screens/map_location_picker.dart` line 39
   - **Problem**: Hardcoded key, may be invalid or restricted
   - **Impact**: Location search/autocomplete won't work

---

## 📋 Step-by-Step Fixes

### **STEP 1: Fix iOS AppDelegate.swift (Duplicate Class)**

**File**: `ios/Runner/AppDelegate.swift`

**Current Issue**: Two AppDelegate class definitions

**Action Required**: Remove duplicate and keep only one with Google Maps initialization

**Expected Result**: iOS app compiles successfully

---

### **STEP 2: Add Google Maps API Key to AndroidManifest.xml**

**File**: `android/app/src/main/AndroidManifest.xml`

**Action Required**: Add meta-data tag inside `<application>` tag

**Expected Result**: Maps load on Android devices

---

### **STEP 3: Verify/Update Google Maps API Key Restrictions**

**Action Required**: Check Google Cloud Console to ensure:
- Maps SDK for Android is enabled
- Maps SDK for iOS is enabled  
- Places API is enabled
- API key restrictions allow your app's package name and SHA-1 fingerprint

**Expected Result**: API keys work correctly

---

### **STEP 4: (Optional) Move API Keys to Environment Variables**

**Action Required**: Use manifestPlaceholders or secure storage instead of hardcoding

**Expected Result**: Better security, easier key rotation

---

## 🗄️ Database-Related Checks

**Note**: Location functionality itself doesn't require database changes. However, verify:

1. **Address Storage**: Check if `AddressStorage` saves/loads correctly
2. **Location Link in Bookings**: Ensure location data is properly linked to bookings

---

## ⚠️ Next Steps

**Please run STEP 1 first and share the result before proceeding to STEP 2.**
