plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.jetbrains.kotlin.android)
  alias(libs.plugins.meta.spatial.plugin)
  alias(libs.plugins.jetbrains.kotlin.plugin.compose)
}

val stagedStudyAudioAssets = layout.buildDirectory.dir("generated/study-audio-assets")
val stagedLocalizedAudioAssets = layout.buildDirectory.dir("generated/localized-audio-assets")
val stageStudyAudioAssets =
    tasks.register<Copy>("stageStudyAudioAssets") {
      from(layout.projectDirectory.dir("../../audio-assets/final")) {
        include("first-big-red-button-vr-study-instructions-final.mp3")
        include("first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3")
      }
      into(stagedStudyAudioAssets)
    }
val stageLocalizedAudioAssets =
    tasks.register<Copy>("stageLocalizedAudioAssets") {
      from(layout.projectDirectory.dir("../../audio-assets/localized")) {
        include("manifest.json")
        include("en_us/**")
        include("ja_jp/**")
        include("shared/**")
        include("stems/**")
      }
      into(stagedLocalizedAudioAssets.map { it.dir("localized") })
    }

android {
  namespace = "org.bigredbutton.firststudy"
  compileSdk = 34

  defaultConfig {
    applicationId = "org.bigredbutton.firststudy"
    minSdk = 34
    targetSdk = 34
    versionCode = 1
    versionName = "0.1.0"

    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    ndkVersion = "27.0.12077973"
    ndk { abiFilters += listOf("arm64-v8a") }
  }

  packaging { resources.excludes.add("META-INF/LICENSE") }

  lint {
    abortOnError = false
    checkReleaseBuilds = false
  }

  buildTypes {
    release {
      isMinifyEnabled = false
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
  }

  buildFeatures {
    buildConfig = true
    compose = true
  }

  sourceSets {
    getByName("main") {
      assets.srcDir(stagedStudyAudioAssets)
      assets.srcDir(stagedLocalizedAudioAssets)
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions { jvmTarget = "17" }
}

dependencies {
  implementation(libs.androidx.core.ktx)
  testImplementation(libs.junit)
  androidTestImplementation(libs.androidx.junit)
  androidTestImplementation(libs.androidx.espresso.core)

  implementation(libs.meta.spatial.sdk.base)
  implementation(libs.meta.spatial.sdk.compose)
  implementation(libs.meta.spatial.sdk.toolkit)
  implementation(libs.meta.spatial.sdk.isdk)
  implementation(libs.meta.spatial.sdk.vr)
  implementation(libs.meta.spatial.sdk.uiset)

  implementation(platform(libs.androidx.compose.bom))
  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.ui)
  implementation(libs.androidx.ui.graphics)
  implementation(libs.androidx.ui.tooling.preview)
  implementation("androidx.appcompat:appcompat:1.7.0")
  implementation("androidx.compose.material:material")
  implementation("androidx.compose.material:material-icons-core:1.7.4")

  androidTestImplementation(platform(libs.androidx.compose.bom))
  androidTestImplementation(libs.androidx.ui.test.junit4)
  debugImplementation(libs.androidx.ui.tooling)
  debugImplementation(libs.androidx.ui.test.manifest)
}

spatial {
  allowUsageDataCollection.set(true)
}

tasks.named("preBuild") {
  dependsOn(stageStudyAudioAssets)
  dependsOn(stageLocalizedAudioAssets)
}
