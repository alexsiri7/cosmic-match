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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            // Properties only set when key.properties exists.
            // buildTypes.release falls back to debug signing when this block is empty.
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
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
