import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("dev.flutter.flutter-gradle-plugin")

}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasReleaseKeystore = keystorePropertiesFile.exists()
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

val developmentFirebaseProjectId = "homevault-aamir-india-1701"
val expectedReleaseFirebaseProjectId =
    System.getenv("HOMEVAULT_FIREBASE_PROJECT_ID")?.trim().orEmpty()
val allowNonProductionRelease =
    System.getenv("HOMEVAULT_ALLOW_NON_PROD_RELEASE")
        ?.equals("true", ignoreCase = true) == true

fun readGoogleServicesProjectId(file: java.io.File): String {
    if (!file.exists()) {
        throw GradleException(
            "Firebase Android configuration is missing: ${file.path}"
        )
    }

    val parsed = JsonSlurper().parse(file) as? Map<*, *>
        ?: throw GradleException("google-services.json is malformed.")
    val projectInfo = parsed["project_info"] as? Map<*, *>
        ?: throw GradleException("google-services.json has no project_info.")
    return projectInfo["project_id"]?.toString()?.trim().orEmpty()
}

fun googleServicesContainsApplicationId(
    file: java.io.File,
    applicationId: String,
): Boolean {
    val parsed = JsonSlurper().parse(file) as? Map<*, *> ?: return false
    val clients = parsed["client"] as? List<*> ?: return false
    return clients.any { clientValue ->
        val client = clientValue as? Map<*, *> ?: return@any false
        val clientInfo = client["client_info"] as? Map<*, *> ?: return@any false
        val androidClientInfo =
            clientInfo["android_client_info"] as? Map<*, *> ?: return@any false
        androidClientInfo["package_name"]?.toString() == applicationId
    }
}

if (releaseBuildRequested) {
    val googleServicesFile = rootProject.file("app/google-services.json")

    if (expectedReleaseFirebaseProjectId.isBlank()) {
        throw GradleException(
            "Release Firebase project is not declared. Set " +
            "HOMEVAULT_FIREBASE_PROJECT_ID before building a release."
        )
    }

    val configuredProjectId = readGoogleServicesProjectId(googleServicesFile)
    if (configuredProjectId != expectedReleaseFirebaseProjectId) {
        throw GradleException(
            "Release Firebase configuration does not match " +
            "HOMEVAULT_FIREBASE_PROJECT_ID."
        )
    }

    if (!googleServicesContainsApplicationId(
            googleServicesFile,
            "com.amuaamir.homevault",
        )
    ) {
        throw GradleException(
            "google-services.json is not registered for com.amuaamir.homevault."
        )
    }

    if (configuredProjectId == developmentFirebaseProjectId &&
        !allowNonProductionRelease
    ) {
        throw GradleException(
            "Release build is targeting the HomeVault development Firebase project. " +
            "Use the production build workflow, or explicitly set " +
            "HOMEVAULT_ALLOW_NON_PROD_RELEASE=true for an internal beta release."
        )
    }
}

if (releaseBuildRequested && !hasReleaseKeystore) {
    throw GradleException(
        "Release signing is not configured. Create android/key.properties " +
        "with the release keystore credentials before building a release."
    )
}

android {
    namespace = "com.amuaamir.homevault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.amuaamir.homevault"
        minSdk = 24
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // This must be created before buildTypes uses it.
    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.1")
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    
}

flutter {
    source = "../.."
}
