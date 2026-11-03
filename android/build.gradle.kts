allprojects {
    repositories {
        google()
        mavenCentral()
        // IJKPlayer 0.8.8 used JCenter, which has been shut down.
        // This read-only mirror is restricted to the original ijkplayer group.
        maven("https://maven.aliyun.com/repository/jcenter") {
            content { includeGroup("tv.danmaku.ijk.media") }
        }
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
