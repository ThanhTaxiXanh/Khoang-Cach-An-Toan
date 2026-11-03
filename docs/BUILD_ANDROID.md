# Android build lock (TTX A500S IJKPlayer)

Flutter stable 3.47 requires Gradle >=8.14 while generated AGP 9 fails on legacy Kotlin Gradle DSL. An earlier attempt with generated AGP 9 failed to compile the legacy Kotlin Gradle DSL. To avoid deprecation errors while validating original IJKPlayer 0.8.8, this project pins:

- Gradle 8.14
- Android Gradle Plugin 8.11.1
- Kotlin Gradle Plugin 2.1.20
- Java 17
- Flutter stable via GitHub Actions

Source files under `android/` contain these pins. The CI command `flutter create --platforms=android ... .` should fill missing generated Android resources without overwriting existing configuration.

After CI build completes, download APK from workflow artifact; until then it is a work in progress. If build cannot resolve `tv.danmaku.ijk.media:ijkplayer-*:0.8.8`, the blocker is its old JCenter distribution. Do NOT copy 70mai's signed proprietary binaries from its XAPK as a workaround. Choose a legally redistributable IJK fork/build instead.
