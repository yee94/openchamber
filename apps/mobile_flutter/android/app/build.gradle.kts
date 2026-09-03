plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val ciVersionCode = System.getenv("OPENCHAMBER_ANDROID_VERSION_CODE")
val ciVersionName = System.getenv("OPENCHAMBER_ANDROID_VERSION_NAME")
val ciKeystorePath = System.getenv("OPENCHAMBER_ANDROID_KEYSTORE_PATH")
val ciKeystorePassword = System.getenv("OPENCHAMBER_ANDROID_KEYSTORE_PASSWORD")
val ciKeyAlias = System.getenv("OPENCHAMBER_ANDROID_KEY_ALIAS")
val ciKeyPassword = System.getenv("OPENCHAMBER_ANDROID_KEY_PASSWORD")
val hasCiSigning = !ciKeystorePath.isNullOrBlank() &&
    !ciKeystorePassword.isNullOrBlank() &&
    !ciKeyAlias.isNullOrBlank() &&
    !ciKeyPassword.isNullOrBlank()

android {
    namespace = "com.yee94.openchamber"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.yee94.openchamber"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = ciVersionCode?.toIntOrNull() ?: flutter.versionCode
        versionName = ciVersionName ?: flutter.versionName
    }

    signingConfigs {
        if (hasCiSigning) {
            create("release") {
                storeFile = file(ciKeystorePath!!)
                storePassword = ciKeystorePassword
                keyAlias = ciKeyAlias
                keyPassword = ciKeyPassword
            }
        }
    }

    buildTypes {
        // Side-by-side with the official Capacitor release (`com.yee94.openchamber`):
        // same applicationIdSuffix convention as packages/mobile (`bun run
        // build:android:debug` → com.yee94.openchamber.debug). Launcher label is
        // "OpenChamber v2" so the Flutter debug icon is distinct from "OpenChamber".
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            resValue("string", "app_name", "OpenChamber v2")
        }
        release {
            if (hasCiSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    val camerax = "1.4.2"
    implementation("androidx.camera:camera-core:$camerax")
    implementation("androidx.camera:camera-camera2:$camerax")
    implementation("androidx.camera:camera-lifecycle:$camerax")
    implementation("androidx.camera:camera-view:$camerax")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
    implementation("com.google.firebase:firebase-messaging:24.1.1")
}
