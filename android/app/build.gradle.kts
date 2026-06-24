import java.io.StringReader
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    // UTF-8 BOM (common when creating key.properties via PowerShell) breaks the first key otherwise.
    val rawText = keystorePropertiesFile.readText(Charsets.UTF_8).removePrefix("\uFEFF")
    keystoreProperties.load(StringReader(rawText))
}
fun Properties.req(name: String): String? =
    getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val storeFileProp = keystoreProperties.req("storeFile")
val storeFileResolved = storeFileProp?.let { rootProject.file(it) }
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    storeFileProp != null &&
    keystoreProperties.req("storePassword") != null &&
    keystoreProperties.req("keyAlias") != null &&
    keystoreProperties.req("keyPassword") != null &&
    storeFileResolved != null &&
    storeFileResolved.exists()

if (!hasReleaseKeystore && keystorePropertiesFile.exists()) {
    logger.warn(
        "android/key.properties exists but release signing is disabled. " +
            "Check storeFile path (relative to android/), passwords, and that the .jks file exists. " +
            "Release builds would fall back to DEBUG signing — Play Console will reject them."
    )
}

android {
    namespace = "com.najizgo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.req("keyAlias")
                keyPassword = keystoreProperties.req("keyPassword")
                storeFile = storeFileResolved
                storePassword = keystoreProperties.req("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.najizgo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] =
            localProperties.getProperty("MAPS_API_KEY", "")
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Provide an SLF4J binder so R8 doesn't fail on StaticLoggerBinder.
    implementation("org.slf4j:slf4j-simple:2.0.13")
    // Match onesignal_flutter (5.5.1 → OneSignal 5.7.7). compileOnly avoids
    // pulling a second SDK copy with Firebase 24 constraints at app level.
    compileOnly("com.onesignal:OneSignal:5.7.7")
}

flutter {
    source = "../.."
}
