import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties =
    Properties().apply {
        if (releaseSigningPropertiesFile.exists()) {
            releaseSigningPropertiesFile.inputStream().use { load(it) }
        }
    }
val releaseBuildRequested =
    gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
val requiredSigningProperties =
    listOf("keyAlias", "keyPassword", "storeFile", "storePassword")

if (releaseBuildRequested) {
    check(releaseSigningPropertiesFile.exists()) {
        "Release signing is required. Create android/key.properties before building."
    }
    val missingSigningProperties =
        requiredSigningProperties.filter {
            releaseSigningProperties.getProperty(it).isNullOrBlank()
        }
    check(missingSigningProperties.isEmpty()) {
        "Missing release signing properties: ${missingSigningProperties.joinToString()}"
    }
}

android {
    namespace = "ai.suilian.suilian_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ai.suilian.suilian_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningPropertiesFile.exists()) {
            create("release") {
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
                storeFile = file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
