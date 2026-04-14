import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.cosmicmatch.app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.cosmicmatch.app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (keyPropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias     = (keyProperties["keyAlias"]     as? String)?.takeIf { it.isNotBlank() } ?: error("key.properties missing: keyAlias")
                keyPassword  = (keyProperties["keyPassword"]  as? String)?.takeIf { it.isNotBlank() } ?: error("key.properties missing: keyPassword")
                storeFile    = file((keyProperties["storeFile"] as? String)?.takeIf { it.isNotBlank() } ?: error("key.properties missing: storeFile"))
                storePassword = (keyProperties["storePassword"] as? String)?.takeIf { it.isNotBlank() } ?: error("key.properties missing: storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
