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

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
