plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.crashlytics") // <--- Así debe verse
}

android {
    namespace = "com.example.music_stereo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

defaultConfig {
        applicationId = "com.example.music_stereo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true // ✨ EL PERMISO PARA APPS GIGANTES

        manifestPlaceholders += mapOf(
            "redirectSchemeName" to "tecconnection",
            "redirectHostName" to "callback"
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")  
      }
    }
}


flutter {
    source = "../.."
}
dependencies {
    implementation(files("libs/spotify-app-remote-release-0.8.0.aar"))
}
