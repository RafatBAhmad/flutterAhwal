plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // يجب أن يبقى آخر واحد
}

android {
    namespace = "com.tariqi.roads" // 🔥 غيّر package name لتطبيق طريقي
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // ✅ هذا السطر هو الأهم لتفعيل desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // 🔥 إعدادات التوقيع
    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "1994rafat"
            storeFile = file("../upload-keystore.jks")
            storePassword = "1994rafat"
        }
    }

    defaultConfig {
        applicationId = "com.tariqi.roads" // 🔥 package name جديد للتطبيق
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = 9 // 🔥 إصدار رقمي
        versionName = "1.0.8" // 🔥 إصدار نصي

        // 🔥 معلومات إضافية للتطبيق
        setProperty("archivesBaseName", "tariqi-roads-v$versionName")
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release") // 🔥 استخدم التوقيع
            isMinifyEnabled = true // 🔥 تقليل حجم التطبيق
            isShrinkResources = true // 🔥 تقليل الموارد
            proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
        }
    }
}

dependencies {
    // ✅ أضف هذا السطر
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    implementation("com.google.android.gms:play-services-ads:23.0.0")
}

flutter {
    source = "../.."
}