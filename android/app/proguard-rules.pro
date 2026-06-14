# ── Flutter core ────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Dart / Flutter obfuscation support ──────────────────────────
# Required when building with --obfuscate
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class dart.** { *; }

# ── VLC Player ──────────────────────────────────────────────────
-keep class org.videolan.** { *; }
-dontwarn org.videolan.**

# ── Firebase ────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Crashlytics — preserve stack traces ─────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# ── Google Mobile Ads ────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── Nearby Connections ───────────────────────────────────────────
-keep class com.google.android.gms.nearby.** { *; }
-dontwarn com.google.android.gms.nearby.**

# ── Audio Service (background playback) ─────────────────────────
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# ── App-specific classes ─────────────────────────────────────────
-keep class com.petersmart.played.BootReceiver { *; }

# ── Hive ─────────────────────────────────────────────────────────
-keep class * extends com.google.flatbuffers.Table { *; }
-keep @com.google.flatbuffers.Struct class * { *; }

# ── Kotlin / Coroutines ──────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ── OkHttp / Dio networking ──────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ── Remove debug logging in release ─────────────────────────────
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
