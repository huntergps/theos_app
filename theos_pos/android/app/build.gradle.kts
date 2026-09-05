import java.util.Properties
import com.android.build.api.dsl.ApplicationExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()
if (releaseSigningPropertiesFile.exists()) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

val releaseSigningKeys = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val hasReleaseSigning = releaseSigningKeys.all {
    releaseSigningProperties.getProperty(it)?.isNotBlank() == true
}
if (releaseSigningPropertiesFile.exists() && !hasReleaseSigning) {
    throw GradleException(
        "android/key.properties exists but is incomplete. " +
            "Copy key.properties.example and provide all release signing values.",
    )
}

extensions.configure<ApplicationExtension> {
    namespace = "tech.galapagos.theosPos"
    // flutter_secure_storage 11 targets Android API 37; keep the app on the
    // highest installed SDK while targetSdk remains managed by Flutter.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "tech.galapagos.theosPos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(
                    releaseSigningProperties.getProperty("storeFile"),
                )
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // CI may build an unsigned artifact when no external signing file
            // is present. A release build is never signed with the debug key.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
