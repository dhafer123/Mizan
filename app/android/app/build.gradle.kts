plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // flutter_gemma bundles engines Mizan never calls: the .litertlm engine
    // (the assistant is a MediaPipe .task model) and RAG (embeddings, text
    // chunking, vector store). Each is loaded only when its API is used, so
    // leaving them out saves about 70 MB per ABI.
    packaging {
        jniLibs {
            excludes += setOf(
                "**/liblitertlm_jni.so",
                "**/libgecko_embedding_model_jni.so",
                "**/libgemma_embedding_model_jni.so",
                "**/libtext_chunker_jni.so",
                "**/libsqlite_vector_store_jni.so",
            )
        }
    }

    namespace = "com.mizan.mizan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs it.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mizan.mizan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // local_auth and flutter_secure_storage need 24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Push notifications need this project's Firebase config (Firebase console >
// Project settings > Android app). Without it the app builds and runs with
// push off (ADR 0011).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
