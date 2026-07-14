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

# just_audio — keep all player classes so release builds don't strip them
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# audio_service — keep service + handler so background playback works in release
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# audio_session
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audio_session.**

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

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Google Mobile Ads — disabled until Play Store launch
# -keep class com.google.android.gms.ads.** { *; }
# -dontwarn com.google.android.gms.ads.**

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
