import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application") version "8.5.2"
    id("org.jetbrains.kotlin.android") version "1.9.24"
}

// Release signing credentials are read from (in priority order):
//   1. Environment variables (used by CI — see docs/dev/05-signing-pipeline.md)
//   2. A local, git-ignored android-app/keystore.properties (developers)
// If neither provides a keystore, the release build is left unsigned so the
// project still configures and `assembleRelease` still runs in CI.
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
fun cred(prop: String, env: String): String? =
    System.getenv(env) ?: keystoreProps.getProperty(prop)

val releaseStoreFile: String? = cred("storeFile", "ANDRAX_KEYSTORE_FILE")

android {
    namespace = "com.andrax.two"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.andrax.two"
        minSdk = 26
        targetSdk = 34
        // versionCode derivation: MAJOR*10000 + MINOR*100 + PATCH (2.0.0 -> 20000)
        // See docs/dev/06-versioning-system.md.
        versionCode = 20000
        versionName = "2.0.0"
    }

    signingConfigs {
        create("release") {
            if (releaseStoreFile != null) {
                storeFile = file(releaseStoreFile)
                storePassword = cred("storePassword", "ANDRAX_KEYSTORE_PASS")
                keyAlias = cred("keyAlias", "ANDRAX_KEY_ALIAS")
                keyPassword = cred("keyPassword", "ANDRAX_KEY_PASS")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Sign the release APK only when credentials are available.
            if (releaseStoreFile != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    // org.json ships with the Android platform — no dependency needed.
}
