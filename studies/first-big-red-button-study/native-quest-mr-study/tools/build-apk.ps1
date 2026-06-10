[CmdletBinding()]
param(
    [string]$JavaHome = 'D:\GithubVR\Immersive video player 0.0.6\.toolchain\jdk-17',
    [string]$AndroidSdkRoot = 'D:\GithubVR\Immersive video player 0.0.6\.toolchain\android-sdk',
    [string]$GradleUserHome = 'D:\GithubVR\Immersive video player 0.0.6\.toolchain\gradle-home',
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gradlew = Join-Path $projectRoot 'gradlew.bat'
if (-not (Test-Path $gradlew)) {
    throw "Gradle wrapper was not found: $gradlew"
}
if (-not (Test-Path (Join-Path $JavaHome 'bin\java.exe'))) {
    throw "JDK was not found. Pass -JavaHome pointing to a JDK 17 install."
}
if (-not (Test-Path (Join-Path $AndroidSdkRoot 'platforms'))) {
    throw "Android SDK was not found. Pass -AndroidSdkRoot pointing to an Android SDK install."
}

$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome 'bin') + ';' + $env:PATH
$env:ANDROID_HOME = $AndroidSdkRoot
$env:ANDROID_SDK_ROOT = $AndroidSdkRoot
$env:GRADLE_USER_HOME = $GradleUserHome

Push-Location $projectRoot
try {
    if ($Clean) {
        & $gradlew clean
        if ($LASTEXITCODE -ne 0) {
            throw "Gradle clean failed with exit code $LASTEXITCODE"
        }
    }

    & $gradlew ':app:assembleDebug'
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle assembleDebug failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$apk = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path $apk)) {
    throw "Expected APK was not produced: $apk"
}

Write-Host "Built APK: $apk"
