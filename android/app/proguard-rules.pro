# Required by flutter_local_notifications 17.x when Android release builds run
# R8. The plugin uses Gson TypeToken for scheduled-notification cache data, so
# generic signatures must be preserved.

## Gson rules
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# Prevent proguard from stripping interface information from TypeAdapter,
# TypeAdapterFactory, JsonSerializer, and JsonDeserializer instances.
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retain generic signatures of TypeToken and its subclasses with R8 3.0+.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
