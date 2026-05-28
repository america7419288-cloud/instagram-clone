# Flutter-specific ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep plugin registrant
-keep class io.flutter.plugins.** { *; }

# Keep our MainActivity
-keep class com.instagramclone.app.MainActivity { *; }

# Prevent stripping annotations used by plugins
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# OkHttp (used by Dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Hive
-keep class com.hivedb.** { *; }
-dontwarn com.hivedb.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
