import java.util.Properties
import java.io.FileInputStream

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Релизная подпись RuStore/Google: скопировать key.properties.example → android/key.properties (не коммитить).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.betment.solitaire"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Магазины распространения: rustore (по умолчанию) и googleplay.
    // Сборки: flutter build appbundle --release --flavor rustore
    //         flutter build appbundle --release --flavor googleplay --dart-define-from-file=config/dart_defines/googleplay.json
    flavorDimensions += "store"
    productFlavors {
        create("rustore") {
            dimension = "store"
        }
        create("googleplay") {
            dimension = "store"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.betment.solitaire"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8: требование качества Google Play (2027) + минус мегабайты:
            // неиспользуемый нативный код магазина-соперника вырезается из флавора.
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

// Новый DSL компилятора Kotlin (kotlinOptions удалён в AGP 9 / KGP 2.2+).
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

// Сборки без --flavor (меню Build → Flutter в Android Studio, `flutter build appbundle`)
// идут через агрегатные задачи AGP: они собирают ОБА флавора, а тул Flutter ищет
// артефакт по пути без флавора (bundle/release, flutter-apk). Складываем туда
// rustore-вариант — магазин по умолчанию, совпадает с дефолтом STORE в Dart.
fun copyFirstExisting(sources: List<File>, target: File) {
    val src = sources.firstOrNull { it.exists() } ?: return
    target.parentFile.mkdirs()
    src.copyTo(target, overwrite = true)
}

val buildDirProvider = layout.buildDirectory
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doLast {
        copyFirstExisting(
            listOf(buildDirProvider.file("outputs/bundle/rustoreRelease/app-rustore-release.aab").get().asFile),
            buildDirProvider.file("outputs/bundle/release/app-release.aab").get().asFile,
        )
    }
}
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        copyFirstExisting(
            listOf(
                buildDirProvider.file("outputs/flutter-apk/app-rustore-release.apk").get().asFile,
                buildDirProvider.file("outputs/apk/rustore/release/app-rustore-release.apk").get().asFile,
            ),
            buildDirProvider.file("outputs/flutter-apk/app-release.apk").get().asFile,
        )
    }
}
tasks.matching { it.name == "assembleDebug" }.configureEach {
    doLast {
        copyFirstExisting(
            listOf(
                buildDirProvider.file("outputs/flutter-apk/app-rustore-debug.apk").get().asFile,
                buildDirProvider.file("outputs/apk/rustore/debug/app-rustore-debug.apk").get().asFile,
            ),
            buildDirProvider.file("outputs/flutter-apk/app-debug.apk").get().asFile,
        )
    }
}
