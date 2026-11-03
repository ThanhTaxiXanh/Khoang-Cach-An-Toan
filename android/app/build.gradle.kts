plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "vn.thanhtaxixanh.ttx_a500s_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    defaultConfig {
        applicationId = "vn.thanhtaxixanh.ttx_a500s_player"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // TEST INSTALLATION ONLY: the previous release APK was unsigned
            // and Android rejected it as an invalid package.
            // Use the Android debug signing key for immediately installable
            // QA builds. Each CI runner generates its own ephemeral key,
            // so future test APK upgrades may need uninstall/reinstall.
            // Production releases MUST use a persistent, private release key.
            signingConfig = signingConfigs.getByName("debug")
            // JNI must see original Java class/member descriptors.
            // Flutter release enables R8 shrinking: keep IJK's JNI surface.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // This is *IJKPlayer*, with RTSP-capable FFmpeg, NOT libVLC / ExoPlayer.
    // Original Bilibili 0.8.8 prebuilt lite FFmpeg omits RTSP demuxing.
    // GSYIjkJava supplies the same tv.danmaku.ijk.media.player.IjkMediaPlayer
    // Java API; ex_so supplies the matched RTSP-enabled FFmpeg/IJK/SDL binaries.
    implementation("io.github.carguo:gsyijkjava:1.0.0")
    runtimeOnly("io.github.carguo:gsyvideoplayer-ex_so:13.2.1")
}
