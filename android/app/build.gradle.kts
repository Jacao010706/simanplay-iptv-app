import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Variante da Google Play: só existe com -Ploja=play (store/google-play/COMO_GERAR.md).
// Sem a propriedade o build é o de sempre (APK do painel, sem flavors, com o atualizador).
val lojaPlay = project.findProperty("loja") == "play"

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

    if (lojaPlay) {
        flavorDimensions += "loja"
        productFlavors {
            create("play") {
                dimension = "loja"
                applicationId = "com.sofae.app"
                // Exigência da Play para apps novos e atualizações desde 31/08/2026 (API 36).
                // O APK do painel continua em 35 até ser testado no Android 16.
                targetSdk = 36
            }
        }
    } else {
        // Atualizador interno (instala o APK baixado); a Play usa src/play/kotlin
        sourceSets["main"].java.srcDir("src/instalador/kotlin")
    }

    // Release da Play só com a chave de envio (key.properties). Sem ela, o fallback abaixo
    // assinaria com a chave de debug, e a Play recusaria o AAB.
    val pedeRelease = gradle.startParameter.taskNames.any { it.contains("Release") }
    if (lojaPlay && pedeRelease && !rootProject.file("key.properties").let { it.exists() && it.length() > 0 }) {
        throw GradleException(
            "Build release da Play sem android/key.properties (chave de envio). " +
                "Veja store/google-play/COMO_GERAR.md."
        )
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

// APK oficial (release) só ARM. O --target-platform do Flutter não filtra as bibliotecas que
// vêm prontas nos plugins (ex.: libmpv do player), e o abiFilters é sobrescrito pelo plugin do
// Flutter; aqui elas saem no empacotamento. O debug (emulador, BUILD_LOCAL.md) mantém o x86_64.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.addAll(listOf("lib/x86_64/**", "lib/x86/**"))
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
