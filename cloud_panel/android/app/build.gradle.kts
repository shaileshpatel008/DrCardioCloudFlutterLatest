import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `flutter build apk --dart-define=DEMO_MODE=true` builds the offline demo
// (clickable prototype). It gets its own app id and name so it can be
// installed next to the live app. Flutter hands the --dart-define values to
// Gradle base64-encoded in the "dart-defines" property.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { encoded ->
        val pair = String(Base64.getDecoder().decode(encoded))
        val i = pair.indexOf('=')
        if (i > 0) pair.substring(0, i) to pair.substring(i + 1) else null
    }
    ?.toMap()
    ?: emptyMap()
val isDemoBuild = dartDefines["DEMO_MODE"] == "true"

android {
    namespace = "com.drcardio.cloudpanel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (isDemoBuild) "com.drcardio.cloudpanel.demo" else "com.drcardio.cloudpanel"
        manifestPlaceholders["appLabel"] = if (isDemoBuild) "Dr. Cardio Demo" else "Dr. Cardio Cloud"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
