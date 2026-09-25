import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── 正式签名（可选） ────────────────────────────────────────────
// 存在 android/key.properties 时启用 release 签名，否则回退 debug 签名。
//
// 为什么必须尽早配好：debug 签名用的是 ~/.android/debug.keystore，
// 换电脑 / 重装系统后签名必然不同 —— 签名不一致的 APK 无法覆盖安装，
// 只能先卸载（账本数据一起没了）。用固定 release 密钥才能长期升级。
//
// key.properties 写法（不入 git，已在 .gitignore 中排除）：
//   storePassword=***
//   keyPassword=***
//   keyAlias=ledger
//   storeFile=ledger-release.jks      # 相对 android/app/ 或写绝对路径
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.ledger"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.ledger"
        // 覆盖安装升级的前提：versionCode 单调递增（读取 pubspec.yaml 的 version）
        minSdk = 23          // Android 6.0，覆盖约 97%+ 现役设备（含 Find X8 Ultra）
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // 未配置密钥时的回退：能装能跑，但不适合长期使用（见文件头说明）
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
