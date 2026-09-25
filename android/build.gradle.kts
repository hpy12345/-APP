allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ── 构建目录重定向（Flutter 官方模板的关键一步，别删）────────────────
//
// 官方 Kotlin DSL 模板原文：
//   val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
//   rootProject.layout.buildDirectory.value(newBuildDir)
//   subprojects { project.layout.buildDirectory.value(newBuildDir.dir(project.name)) }
//
// 为什么必须有：
//   `flutter build apk` 只会在 <Flutter 工程根>/build/app/outputs/flutter-apk/ 下找 APK。
//   没有这段重定向时，AGP 把产物留在 android/app/build/outputs/ ，
//   而 Flutter 去看 <工程根>/build/ —— 差了整整一层，于是报
//     "Gradle build failed to produce an .apk file. It's likely that this file was
//      generated under <工程根>/build, but the tool couldn't find it."
//   注意 Gradle 本身是**成功退出**的，日志里一条报错都没有，极难定位。
//   （本项目 2026-09-25 就踩了这个坑，靠 CI 里加的产物兜底步骤才反推出原因。）
//
// "android/build" + "../../build" 解析到 <Flutter 工程根>/build。
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(newBuildDir.dir(project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
