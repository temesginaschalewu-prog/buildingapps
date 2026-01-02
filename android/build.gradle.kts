allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ADD THIS buildscript block at the TOP of the file:
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ADD the Google services classpath
        classpath("com.google.gms:google-services:4.4.2")
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