import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.firebase:firebase-crashlytics-gradle:2.9.9")
    }
}
// ✨ EL ESCUDO CONTRA PAQUETES DESACTUALIZADOS (Versión Instantánea)
subprojects {
    pluginManager.withPlugin("com.android.library") {
        configure<com.android.build.gradle.LibraryExtension> {
            if (namespace == null) {
                namespace = project.group.toString()
            }
        }
    }
}