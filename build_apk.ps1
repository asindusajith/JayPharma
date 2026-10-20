# ====================================================================
# JAY PHARMA - Android APK Release Build Script
# ====================================================================

$ErrorActionPreference = "Stop"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  JAY PHARMA - BUILDING RELEASE APK                   " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set Java 17 and Android SDK environment
$javaHome = "D:\My Projects\erp-maintains\java\jdk-17.0.2"
$sdkHome = "D:\My Projects\erp-maintains\android-sdk"

if (Test-Path $javaHome) {
    $env:JAVA_HOME = $javaHome
    $env:Path = "$javaHome\bin;$env:Path"
    Write-Host "[OK] Using Java 17: $javaHome" -ForegroundColor Green
} else {
    Write-Host "[!] Java 17 path not found: $javaHome" -ForegroundColor Red
}

if (Test-Path $sdkHome) {
    $env:ANDROID_HOME = $sdkHome
    $env:Path = "$sdkHome\cmdline-tools\latest\bin;$sdkHome\platform-tools;$env:Path"
    Write-Host "[OK] Using Android SDK: $sdkHome" -ForegroundColor Green
}

Set-Location $scriptDir

Write-Host "`n[*] Running: flutter build apk --release..." -ForegroundColor Yellow
& flutter build apk --release

$sourceApk = Join-Path $scriptDir "build\app\outputs\flutter-apk\app-release.apk"

if (Test-Path $sourceApk) {
    $apkSize = [math]::Round((Get-Item $sourceApk).Length / 1MB, 2)
    Write-Host "`n[√] Release APK successfully built! ($apkSize MB)" -ForegroundColor Green

    # Copy to project root
    $rootApk = Join-Path $scriptDir "jaypharma.apk"
    Copy-Item -Path $sourceApk -Destination $rootApk -Force
    Write-Host "[OK] Copied to project root: $rootApk" -ForegroundColor Green

    # Copy to IIS web directory for easy public mobile download
    $iisDir = "C:\inetpub\wwwroot\jaypharma"
    if (Test-Path $iisDir) {
        Copy-Item -Path $sourceApk -Destination (Join-Path $iisDir "jaypharma.apk") -Force
        Copy-Item -Path $sourceApk -Destination (Join-Path $iisDir "app-release.apk") -Force
        Write-Host "[OK] Deployed to IIS for direct download:" -ForegroundColor Green
        Write-Host "     http://220.247.236.89:83/jaypharma/jaypharma.apk" -ForegroundColor Yellow
        Write-Host "     http://localhost:83/jaypharma/jaypharma.apk" -ForegroundColor Yellow
    }
} else {
    Write-Host "[X] APK file was not found at $sourceApk" -ForegroundColor Red
    exit 1
}
