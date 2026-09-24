import java.io.FileReader
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tomker.artistsaas"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tomker.artistsaas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Figé explicitement (Android 7.0) : la valeur par défaut de Flutter peut
        // évoluer à chaque montée de version du SDK. Couvre la quasi-totalité du
        // parc et conditionne le support des plugins audio/stockage.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Configuration de signature pour les builds release.
        // Lit android/key.properties si le fichier existe ; sinon,
        // bascule sur la clé debug pour que `flutter run --release`
        // et `flutter build apk` fonctionnent sans keystore productif.
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties()
                keyProperties.load(FileReader(keyPropertiesFile))
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            } else {
                storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // Multi-artistes : chaque artiste est distribué comme une application
    // distincte (identifiant + nom + icône propres) générée depuis la même
    // base de code via les flavors.
    flavorDimensions += "artist"

    productFlavors {
        create("artist1") {
            dimension = "artist"
            applicationId = "com.music.artist1"
            resValue("string", "app_name", "Artist 1")
        }
        create("artist2") {
            dimension = "artist"
            applicationId = "com.music.artist2"
            resValue("string", "app_name", "Artist 2")
        }
        create("artist3") {
            dimension = "artist"
            applicationId = "com.music.artist3"
            resValue("string", "app_name", "Artist 3")
        }
        create("artist4") {
            dimension = "artist"
            applicationId = "com.music.artist4"
            resValue("string", "app_name", "Artist 4")
        }
        create("artist5") {
            dimension = "artist"
            applicationId = "com.music.artist5"
            resValue("string", "app_name", "Artist 5")
        }
        create("artist6") {
            dimension = "artist"
            applicationId = "com.music.artist6"
            resValue("string", "app_name", "Artist 6")
        }
        create("artist7") {
            dimension = "artist"
            applicationId = "com.music.artist7"
            resValue("string", "app_name", "Artist 7")
        }
        create("artist8") {
            dimension = "artist"
            applicationId = "com.music.artist8"
            resValue("string", "app_name", "Artist 8")
        }
        create("artist9") {
            dimension = "artist"
            applicationId = "com.music.artist9"
            resValue("string", "app_name", "Artist 9")
        }
        create("artist10") {
            dimension = "artist"
            applicationId = "com.music.artist10"
            resValue("string", "app_name", "Artist 10")
        }
        create("dilson_le_mustang") {
            dimension = "artist"
            applicationId = "com.music.dilson_le_mustang"
            resValue("string", "app_name", "Dilson Le Mustang")
        }
        create("jethsonat") {
            dimension = "artist"
            applicationId = "com.music.jethsonat"
            resValue("string", "app_name", "Jethsonat")
        }
    }
}

flutter {
    source = "../.."
}
