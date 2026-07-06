# Flutter Web Auth 2 — force newer version compatible with Kotlin 2.x
-keep class com.linusu.flutter_web_auth_2.** { *; }

# Appwrite SDK
-keep class io.appwrite.** { *; }
-dontwarn io.appwrite.**

# Nearby Connections
-keep class com.google.android.gms.nearby.** { *; }

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

# flutter_vlc_player — keep VLC native bridge
-keep class org.videolan.libvlc.** { *; }
-dontwarn org.videolan.libvlc.**

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Google Mobile Ads — disabled until Play Store launch
# -keep class com.google.android.gms.ads.** { *; }
# -dontwarn com.google.android.gms.ads.**

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
