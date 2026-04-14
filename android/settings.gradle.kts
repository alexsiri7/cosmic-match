pluginManagement {
    val flutterSdkPath: String = run {
        val propsFile = file("local.properties")
        require(propsFile.exists()) {
            "local.properties not found. Run `flutter pub get` or set flutter.sdk manually."
        }
        val properties = java.util.Properties()
        propsFile.inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
            ?: error("flutter.sdk not set in local.properties")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
