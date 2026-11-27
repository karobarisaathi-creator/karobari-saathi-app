import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the Google Services plugin
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.let {
    project.file(it)
}
val requiredSigningProperties = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
)
val missingSigningProperties = requiredSigningProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val hasReleaseSigning = missingSigningProperties.isEmpty() &&
    releaseStoreFile?.exists() == true
if (releaseTaskRequested && (!keystorePropertiesFile.exists() || !hasReleaseSigning)) {
    throw GradleException(
        "Release builds require android/key.properties with all signing values. " +
            "Missing: ${missingSigningProperties.joinToString()}" +
            if (releaseStoreFile?.exists() == false) {
                "; storeFile does not exist"
            } else {
                ""
            },
    )
}

android {
    namespace = "com.zalooq.account_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    externalNativeBuild {
        cmake {
            version = "3.31.0"
        }
    }

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildFeatures {
        compose = false
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zalooq.account_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // MultiDex support
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                 signingConfig = signingConfigs.getByName("release")
            } else {
                 signingConfig = null
            }
            // Enabling code shrinking (ProGuard/R8) for smaller APK
            isMinifyEnabled = true 
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
        // Required for Firebase BOM
        implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    }
}

flutter {
    source = "../.."
}
