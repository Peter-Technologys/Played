# Hive
-keep class hive.** { *; }
-keep class com.hivedb.** { *; }

# Flutter core — keep all plugin registrars and embedding classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
# Plugin registrars are loaded by class name via reflection
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
# All Android components declared in AndroidManifest are loaded by name
-keep class * extends android.app.Service { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.content.ContentProvider { *; }
-keep class * extends android.app.Activity { *; }

# audio_service — keep service + handler so background playback works in release
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# media_kit — keep ALL subpackages (video + core + native bridge)
-keep class com.alexmercerind.media_kit.** { *; }
-dontwarn com.alexmercerind.media_kit.**
-keep class com.alexmercerind.media_kit_video.** { *; }
-dontwarn com.alexmercerind.media_kit_video.**
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }
-dontwarn com.alexmercerind.media_kit_libs_android_video.**
# Keep native method names so JNI calls survive R8
-keepclasseswithmembernames class * {
    native <methods>;
}

# mobile_scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# ── App classes (workers, receivers, services, activities) ───────────────
# Explicit keeps for all app-defined classes.
# Preserve the app activity, native media bridge and notification receiver.
-keep class com.otyaplayer.app.** { *; }
-keep class com.otyaplayer.app.MainActivity { *; }
-keep class com.otyaplayer.app.NotificationDismissReceiver { *; }

# connectivity_plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# package_info_plus / device_info_plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class dev.fluttercommunity.plus.deviceinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# Firebase MessagingService subclass (referenced by name in AndroidManifest)
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**
# Fix #13: keep Android KeyStore provider classes used by reflection inside
# flutter_secure_storage. Without these rules R8 strips the class names and
# the KeyStore provider lookup fails silently in release builds.
-keep class android.security.keystore.** { *; }
-keep class java.security.KeyStore { *; }
-keep class java.security.KeyStore$* { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Google Sign-In, Firebase and local_auth (Google Play Services)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# local_auth — biometric classes
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Encrypt / Bouncy Castle (used by vault)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# Remove all logging in release to shrink further
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# WebView (webview_flutter + webview_flutter_android)
# Keep WebView JavaScript interface classes so JS bridge survives R8.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# Firebase (firebase_core + firebase_messaging)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
