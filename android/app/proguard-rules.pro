# Flutter specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Just Audio plugin
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.jcraft.jzlib.** { *; }

# Keep Geolocator plugin
-keep class com.baseflow.geolocator.** { *; }

# Keep Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep our app classes
-keep class com.example.adhan_app.** { *; }

# Keep media session for volume button handling
-keep class androidx.media.** { *; }

# Prevent R8 from removing classes used via reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exception

# Ignore missing Play Core classes (not used in this app)
-dontwarn com.google.android.play.core.**

# Ignore missing classes from deferred components (not used)
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
