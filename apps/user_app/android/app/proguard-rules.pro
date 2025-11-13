# Keep annotations used by SDKs
-keep class proguard.annotation.** { *; }

# Razorpay SDK recommended rules (defensive)
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Gson / reflection safety (common in SDKs)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-dontwarn sun.misc.Unsafe

# OkHttp/Okio/Retrofit (if transitively present)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class retrofit2.** { *; }

# Deep Linking / App Links - Keep MainActivity and intent handling
-keep class com.mycompany.saralevents.MainActivity { *; }
-keep class * extends android.app.Activity
-keep class * extends android.app.Fragment
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Flutter deep linking classes
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep app_links package classes (if using native code)
-keep class com.llfbandit.app_links.** { *; }
-dontwarn com.llfbandit.app_links.**

# Keep intent filter classes
-keepclassmembers class * extends android.app.Activity {
    public void *(android.content.Intent);
}

# Keep URI handling
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Flutter Play Store Split Application (deferred components) - ignore if not using
# These classes are only needed for Play Feature Delivery, which we're not using
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**

# Exclude FlutterPlayStoreSplitApplication if not using deferred components
-assumenosideeffects class io.flutter.embedding.android.FlutterPlayStoreSplitApplication {
    <init>();
}
-assumenosideeffects class io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager {
    *;
}
