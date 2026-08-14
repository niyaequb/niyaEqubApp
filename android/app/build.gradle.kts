import java.util.Properties

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
    namespace = "com.niyaet.ekub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.projectDir.resolve("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { input ->
            keystoreProperties.load(input)
        }
    }

    // A release build is only signed with the upload key when key.properties
    // exists AND the keystore it points at is actually on disk.
    //
    // key.properties is gitignored and holds the signing password, so it is
    // absent on a fresh clone and on CI. Previously the "release" signing
    // config was created regardless, which left storeFile null and failed the
    // build at packageRelease with:
    //
    //   SigningConfig "release" is missing required property "storeFile".
    //
    // That made `flutter run --release` impossible to use for local testing,
    // even though local testing never needs the real upload key.
    val storeFilePath = keystoreProperties.getProperty("storeFile")
    val resolvedStoreFile = storeFilePath?.let { path ->
        val candidate = file(path)
        if (candidate.exists()) candidate else rootProject.projectDir.resolve(path)
    }
    val hasUploadKey = resolvedStoreFile?.exists() == true &&
        !keystoreProperties.getProperty("keyAlias").isNullOrBlank()

    if (!hasUploadKey) {
        logger.lifecycle(
            "Release signing: no usable keystore found (android/key.properties). " +
            "Signing release builds with the debug key \u2014 fine for local testing, " +
            "NOT publishable to Play."
        )
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = resolvedStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.niyaet.ekub"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Side-by-side test builds.
        //
        //     flutter build apk --release -PsideloadTest
        //
        // Gives the APK a different applicationId, so it installs NEXT TO the
        // Play Store copy instead of colliding with it. Two problems go away
        // at once:
        //
        //   1. An APK signed with your upload key cannot replace one Play
        //      signed with the app signing key — Android refuses it with
        //      INSTALL_FAILED_UPDATE_INCOMPATIBLE. Different id, no conflict.
        //   2. The tester keeps a working app. Handing a client a build that
        //      replaces the one they depend on, and then watching it crash,
        //      costs more than the test is worth.
        //
        // PREREQUISITE: add com.niyaet.ekub.test as an Android app in the
        // Firebase console and re-download google-services.json. The
        // google-services plugin fails the build with "No matching client
        // found for package name" otherwise — it will not fall back.
        //
        // Both apps carry the same name and icon in the launcher, so keep
        // track of which is which. This build is NOT publishable: a different
        // applicationId is a different app to Play.
        if (project.hasProperty("sideloadTest")) {
            applicationIdSuffix = ".test"

            // Fail now, not in two and a half minutes.
            //
            // Without this check the build runs all the way to
            // :app:processReleaseGoogleServices before dying with "No matching
            // client found for package name 'com.niyaet.ekub.test'" — which is
            // accurate but says nothing about where to go or what to do, after
            // a wait long enough to make you doubt the flag itself.
            val servicesFile = project.file("google-services.json")
            val testPackage = "com.niyaet.ekub.test"
            if (servicesFile.exists() && !servicesFile.readText().contains(testPackage)) {
                throw GradleException(
                    """

                    Side-by-side test build needs one more step.

                    google-services.json only knows about com.niyaet.ekub, and
                    -PsideloadTest builds as $testPackage. The Firebase plugin
                    refuses to build an app it has no config for.

                    Add it once, and it stays added:

                      1. console.firebase.google.com -> niya-equb
                      2. Project settings -> General -> Your apps -> Add app -> Android
                      3. Package name: $testPackage
                         (nickname and SHA-1 can be left blank)
                      4. Download google-services.json
                      5. Replace android/app/google-services.json with it

                    The new file carries BOTH package names, so normal release
                    builds keep working exactly as before.

                    To build without the test package, drop -PsideloadTest.

                    """.trimIndent()
                )
            }

            logger.lifecycle(
                "Side-by-side test build: applicationId is " +
                "$testPackage \u2014 installs alongside the Play version, " +
                "and cannot be uploaded to Play."
            )
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no upload keystore is present,
            // so `flutter run --release` works on any machine. A Play Store
            // build must have android/key.properties in place — check the
            // "Release signing" line in the Gradle log to confirm which key
            // was used.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Shrinking was ALREADY running on release before this block
            // existed — the Flutter Gradle plugin turns it on — but nothing
            // pointed R8 at any app-level keep rules. Confirm for yourself in
            // build/app/outputs/mapping/release/configuration.txt: the final
            // section reads "the proguard configuration file ... is <unknown>"
            // and is empty. That is the app contributing nothing.
            //
            // proguard-rules.pro is inert unless it is named here. Declaring
            // both flags explicitly rather than inheriting them also means the
            // behaviour is visible in this file instead of hidden in the
            // plugin's defaults.
            //
            // Consequence of the old setup: R8 obfuscated the
            // com.dexterous.flutterlocalnotifications model classes that the
            // scheduled-azan alarm deserialises with Gson at fire time, and
            // the resource shrinker was free to drop res/raw/azan.wav. Both
            // fail silently, and neither can happen in debug because debug is
            // not minified. Hence "works in flutter run, dead in --release".
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }

        debug {
            // Stated explicitly so the debug/release difference is impossible
            // to misread. This is the whole reason the adhan worked in
            // `flutter run` and not in `flutter run --release`.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
