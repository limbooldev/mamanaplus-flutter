import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "com.mamanaplus.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.mamanaplus.android"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val storeFilePath = localProperties.getProperty("storeFile")?.trim().orEmpty()
    signingConfigs {
        if (storeFilePath.isNotEmpty()) {
            create("releaseStore") {
                keyAlias = localProperties.getProperty("keyAlias")
                keyPassword = localProperties.getProperty("keyPassword")
                storeFile = file(storeFilePath)
                storePassword = localProperties.getProperty("storePassword")
            }
        }
    }

    val storeSigning = signingConfigs.findByName("releaseStore")

    buildTypes {
        named("debug") { }
        // Use named("profile") — bare `profile` clashes with Kotlin Multiplatform Gradle DSL.
        named("profile") {
            signingConfig = storeSigning ?: signingConfigs.getByName("debug")
        }
        named("release") {
            signingConfig = storeSigning ?: signingConfigs.getByName("debug")
        }
    }

    flavorDimensions += "default"
    productFlavors {
        create("dev") {
            dimension = "default"
            versionNameSuffix = "-dev"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".profile"
            versionNameSuffix = "-profile"
        }
        create("prod") {
            dimension = "default"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
