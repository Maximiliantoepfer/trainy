import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter removes device-test APKs on teardown. Never share the installed app's
// package/data directory, even when tests use an isolated SQLite database.
val targetPath = (project.findProperty("target") as? String).orEmpty().replace('\\', '/')
// flutter test builds a temporary listener.dart, not the original target path.
val dartDefines = (project.findProperty("dart-defines") as? String).orEmpty().split(',').mapNotNull {
    runCatching { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }.getOrNull()
}
val integrationTarget = targetPath.startsWith("integration_test/") || targetPath.contains("/integration_test/") ||
    dartDefines.any { it.startsWith("INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=") }

android {
    namespace = "com.example.trainy"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        applicationId = if (integrationTarget) "com.example.trainy.integration" else "com.example.trainy"
        manifestPlaceholders["trainyLabel"] = if (integrationTarget) "Trainy (Tests)" else "trainy"
        minSdk = 26
        targetSdk = 35           // optional explizit
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}

flutter {
    source = "../.."
}

// Local integration tests do not initialize Firebase or use production accounts.
tasks.matching { it.name.endsWith("GoogleServices") }.configureEach {
    enabled = !integrationTarget
}

dependencies {
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
