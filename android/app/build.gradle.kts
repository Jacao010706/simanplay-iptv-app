import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.simanplay.iptvplayer.iptv_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        val keyPropertiesFile = rootProject.file("key.properties")
        if (keyPropertiesFile.exists() && keyPropertiesFile.length() > 0) {
            create("release") {
                val keyProperties = Properties()
                keyProperties.load(FileInputStream(keyPropertiesFile))
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    defaultConfig {
        // applicationId de cada revendedor: vem do painel pelo workflow (APPLICATION_ID).
        // Sem a variável (build local), usa o ID antigo, que ficou só com o PRIMETV.
        applicationId = System.getenv("APPLICATION_ID")?.takeIf { it.isNotBlank() }
            ?: "com.simanplay.iptvplayer.iptv_player"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val keyPropertiesFile = rootProject.file("key.properties")
            signingConfig = if (keyPropertiesFile.exists() && keyPropertiesFile.length() > 0) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Bibliotecas nativas (.so) comprimidas dentro do APK: o download cai de ~62 MB para ~29 MB.
    // O Android extrai as bibliotecas na instalação (extractNativeLibs=true no manifesto final).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider usado na instalacao da atualizacao (OTA)
    implementation("androidx.core:core:1.13.1")
}
