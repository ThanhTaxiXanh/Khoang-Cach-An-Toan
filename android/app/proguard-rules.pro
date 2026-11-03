# IJKPlayer 0.8.8 uses JNI name-based lookups and RegisterNatives.
# R8 must never rename/strip any of these classes, methods or fields.
# See upstream IJK issue #1656 and native J4A_LoadAll implementation.
-keep class tv.danmaku.ijk.media.** { *; }

# Keep JNI entrypoints in dependencies that use native keyword.
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepattributes Signature,InnerClasses,EnclosingMethod
