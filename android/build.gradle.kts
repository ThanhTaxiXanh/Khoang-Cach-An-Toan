allprojects {
    repositories {
        google()
        mavenCentral()
        // IJKPlayer RTSP build is published on Maven Central by GSYVideoPlayer.
        // No JCenter, libVLC, Media3 or original 70mai binaries required.
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)
subprojects {
    project.layout.buildDirectory.value(newBuildDir.dir(project.name))
    project.evaluationDependsOn(":app")
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
