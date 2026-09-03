plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
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
