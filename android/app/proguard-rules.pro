# KopiyanteaPOS — ProGuard / R8 rules
#
# Wire from android/app/build.gradle:
#   buildTypes {
#     release {
#       minifyEnabled true
#       shrinkResources true
#       proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
#                     'proguard-rules.pro'
#     }
#   }
#
# Add new -keep rules below when adding native-bridged packages that get
# stripped by R8 (you'll see runtime ClassNotFoundException / NoSuchMethodError).

# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Drift / SQLite (sqlite3_flutter_libs) ────────────────────────────────────
-keep class com.tekartik.** { *; }
-dontwarn com.tekartik.**

# ── Supabase / GoTrue / Postgrest ────────────────────────────────────────────
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ── Bluetooth Thermal Printer ────────────────────────────────────────────────
-keep class br.com.sjr.print_bluetooth_thermal.** { *; }
-dontwarn br.com.sjr.print_bluetooth_thermal.**

# ── Mobile Scanner (camera + MLKit) ──────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**

# ── permission_handler ───────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── flutter_secure_storage ───────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── Freezed / json_serializable runtime ──────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ── kotlinx.serialization (used transitively by Supabase) ────────────────────
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keep,includedescriptorclasses class **$$serializer { *; }
-keepclassmembers class * {
    *** Companion;
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# ── Generic cleanups ─────────────────────────────────────────────────────────
-dontwarn org.codehaus.mojo.animal_sniffer.*
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**

# Strip Logger noise from release builds (we already gate by APP_ENV but the
# string literals stay in the binary otherwise).
-assumenosideeffects class io.flutter.Log {
    public static *** d(...);
    public static *** v(...);
}
