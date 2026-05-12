plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        
        // EL PASE VIP PARA SPOTIFY (VERSIÓN KOTLIN CORRECTA)
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
apply plugin: 'com.google.firebase.crashlytics'