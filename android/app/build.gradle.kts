plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val isReminderAttestationBuild =
    providers.gradleProperty("PARKINSUM_REMINDER_ATTESTATION")
        .map { it.equals("true", ignoreCase = true) }
        .getOrElse(false)
val configuredApplicationId =
    if (isReminderAttestationBuild) {
        "com.parkinsum.companion.reminderattestation"
    } else {
        "com.parkinsum.companion"
    }
val configuredApplicationLabel =
    if (isReminderAttestationBuild) {
        "ParkinSUM Reminder Attestation"
    } else {
        "ParkinSUM Companion"
    }

android {
    namespace = "com.parkinsum.companion"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = configuredApplicationId
        manifestPlaceholders["applicationLabel"] = configuredApplicationLabel
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
