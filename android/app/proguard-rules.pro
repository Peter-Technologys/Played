# Flutter Web Auth 2 — force newer version compatible with Kotlin 2.x
-keep class com.linusu.flutter_web_auth_2.** { *; }

# Appwrite SDK
-keep class io.appwrite.** { *; }
-dontwarn io.appwrite.**

# nearby_connections — REMOVED (not in pubspec; replaced by pure-Dart Flash Share)

# Hive
-keep class hive.** { *; }
-keep class com.hivedb.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# just_audio — REMOVED (replaced by media_kit for audio playback)

# audio_service — keep service + handler so background playback works in release
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# audio_session — REMOVED (was only needed by just_audio)

# flutter_vlc_player — REMOVED (not in pubspec; flutter_vlc_player replaced by media_kit)

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

# workmanager
-keep class be.tramckrijte.workmanager.** { *; }
-dontwarn be.tramckrijte.workmanager.**
# Keep our own WorkManager worker so R8 does not rename it
-keep class com.otyaplayer.app.UpdateCheckWorker { *; }
# Keep BroadcastReceivers declared in AndroidManifest
-keep class com.otyaplayer.app.BootReceiver { *; }
-keep class com.otyaplayer.app.NotificationDismissReceiver { *; }

# open_filex
-keep class com.crazecoder.openfile.** { *; }
-dontwarn com.crazecoder.openfile.**

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

# Google Mobile Ads + local_auth (Google Play Services)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# androidx.startup — required by WorkManagerInitializer declared in AndroidManifest
-keep class androidx.startup.** { *; }
-dontwarn androidx.startup.**

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

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
