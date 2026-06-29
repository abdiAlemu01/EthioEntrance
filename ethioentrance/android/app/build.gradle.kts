
// andriod app build.gradle.kts
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "Abdi_Alemu.com.EthioEntrance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ❌ REMOVE THE ENTIRE OLD KOTLINOPTIONS BLOCK FROM HERE

    defaultConfig {
        applicationId = "Abdi_Alemu.com.EthioEntrance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

//  ADD THIS NEW BLOCK AT THE ROOT LEVEL (BELOW THE ANDROID BLOCK)
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}