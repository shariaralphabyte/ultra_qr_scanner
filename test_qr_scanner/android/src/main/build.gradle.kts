apply(plugin = "com.android.library")
apply(plugin = "kotlin-android")
apply(plugin = "dev.flutter.flutter-gradle-plugin")

android {
    namespace = "com.shariar99.ultra_qr_scanner"

    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
        getByName("test").java.srcDirs("src/test/kotlin")
    }

    defaultConfig {
        minSdk = 21
    }

    dependencies {
        implementation("androidx.camera:camera-core:1.3.1")
        implementation("androidx.camera:camera-camera2:1.3.1")
        implementation("androidx.camera:camera-lifecycle:1.3.1")
        implementation("androidx.camera:camera-view:1.3.1")
        implementation("com.google.mlkit:barcode-scanning:17.2.0")
        implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")
        testImplementation("org.jetbrains.kotlin:kotlin-test")
        testImplementation("org.mockito:mockito-core:5.0.0")
    }

    testOptions {
        unitTests.all {
            useJUnitPlatform()

            testLogging {
                events("passed", "skipped", "failed", "standardOut", "standardError")
                outputs.upToDateWhen { false }
                showStandardStreams = true
            }
        }
    }
}