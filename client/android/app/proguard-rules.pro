# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-keep class io.flutter.plugin.** { *; }

# Keep MainActivity
-keep class com.hadoom.mit.MainActivity { *; }

# Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
