# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Dart / Flutter engine ─────────────────────────────────────────────────────
-dontwarn io.flutter.embedding.**
-keep class io.flutter.embedding.** { *; }

# ── ZCS SmartPOS SDK (printer) ────────────────────────────────────────────────
-keep class com.zcs.sdk.** { *; }
-dontwarn com.zcs.sdk.**

# ── Paytm EDC SDK (if AAR is added later) ────────────────────────────────────
-keep class com.paytm.** { *; }
-dontwarn com.paytm.**

# ── App model classes ─────────────────────────────────────────────────────────
# Keeps all classes in the app package from being renamed so that stack traces
# remain readable when reporting issues to Paytm's compliance team.
-keep class com.hadoom.mit.** { *; }

# ── General Android / Kotlin ──────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ── Prevent stripping serialisable data classes ───────────────────────────────
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
