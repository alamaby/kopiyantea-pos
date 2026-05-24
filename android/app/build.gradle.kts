import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

fun String.toApkNameSegment(): String =
    trim()
        .replace(Regex("""[^\w.-]+"""), "-")
        .trim('-')
        .ifBlank { "app" }

fun String.toTaskNameSegment(): String =
    replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }

val appDisplayName: Provider<String> = providers.provider {
    val manifest = project.file("src/main/AndroidManifest.xml")
    val label = Regex("""android:label="([^"]+)"""")
        .find(manifest.readText())
        ?.groupValues
        ?.get(1)

    (label ?: rootProject.name).toApkNameSegment()
}

android {
    namespace = "com.alamaby.kopiyantea_pos"
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
        applicationId = "com.alamaby.kopiyantea_pos"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = rootProject.file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isEmpty) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

android.buildTypes.configureEach {
    val buildTypeName = name
    val buildTypeTaskName = buildTypeName.toTaskNameSegment()
    val renameTask = tasks.register<Copy>("copyRenamed${buildTypeTaskName}Apk") {
        group = "build"
        description = "Copies the $buildTypeName APK with app name, version, and build number."

        val versionName = providers.provider { android.defaultConfig.versionName ?: "0.0.0" }
        val versionCode = providers.provider { android.defaultConfig.versionCode?.toString() ?: "0" }

        from(layout.buildDirectory.dir("outputs/apk/$buildTypeName")) {
            include("app-$buildTypeName.apk")
            rename {
                "${appDisplayName.get()}-v${versionName.get()}+${versionCode.get()}-$buildTypeName.apk"
            }
        }
        into(layout.buildDirectory.dir("outputs/flutter-apk"))
    }

    tasks.matching { it.name == "assemble$buildTypeTaskName" }.configureEach {
        finalizedBy(renameTask)
    }
}
