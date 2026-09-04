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

fun configureSubprojectAndroid(proj: Project) {
    if (proj.name == "nfc_manager") {
        val android = proj.extensions.findByName("android") ?: return
        try {
            val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
            method.invoke(android, 37)
        } catch (_: Throwable) {
            try {
                val method = android.javaClass.getMethod("setCompileSdk", Int::class.javaObjectType)
                method.invoke(android, 37)
            } catch (_: Throwable) {}
        }
    }
}

subprojects {
    if (project.name != "app") {
        if (project.state.executed) {
            configureSubprojectAndroid(project)
        } else {
            project.afterEvaluate {
                configureSubprojectAndroid(project)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
