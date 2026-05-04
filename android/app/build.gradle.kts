import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("io.sentry.android.gradle") version "6.6.0"
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "net.interstellarai.cosmicmatch"
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
        applicationId = "net.interstellarai.cosmicmatch"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties.getProperty("keyAlias")
                    ?: error("keyAlias missing from android/key.properties — see key.properties.example")
                keyPassword = keyProperties.getProperty("keyPassword")
                    ?: error("keyPassword missing from android/key.properties")
                storeFile = file(keyProperties.getProperty("storeFile")
                    ?: error("storeFile missing from android/key.properties"))
                storePassword = keyProperties.getProperty("storePassword")
                    ?: error("storePassword missing from android/key.properties")
            }
        }
    }

    buildTypes {
        release {
            // SYMBOL_TABLE embeds function-name symbols inside the AAB (under
            // BUNDLE-METADATA/com.android.tools.build.debugsymbols/). Play Console
            // extracts them at upload, clearing the "no debug symbols" warning.
            // FULL would also embed line numbers but ballooned AAB size and tripped
            // a Flutter 3.32-era regression (flutter/flutter#169252).
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

// sentry_flutter (8.14.2) bundles its own sentry-android SDK; autoInstallation
// would re-add a conflicting copy. autoUploadProguardMapping uploads the R8
// mapping.txt to Sentry on every release build using SENTRY_AUTH_TOKEN/ORG/PROJECT
// from the environment (set in .github/workflows/ci.yml). uploadNativeSymbols stays
// off because the Flutter SDK doesn't support it — native symbols go to Play Console
// only, via the buildTypes.release.ndk block above.
sentry {
    autoInstallation { enabled.set(false) }
    includeProguardMapping.set(true)
    autoUploadProguardMapping.set(true)
    uploadNativeSymbols.set(false)
    org.set("alex-siri")
    projectName.set("cosmic-match")
}

flutter {
    source = "../.."
}
