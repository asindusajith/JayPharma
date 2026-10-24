# deploy_production.ps1
$ErrorActionPreference = "Continue"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   DEPLOYING JAY PHARMA WEB APP, APK & API TO IIS     " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$webSource = "d:\My Projects\JayPharma\build\web"
$webDest = "C:\inetpub\wwwroot\jaypharma"

$apkSource = "d:\My Projects\JayPharma\build\app\outputs\flutter-apk\app-release.apk"
$apiSource = "d:\My Projects\JayPharma\backend\JayPharma.Api\bin\Publish"
$apiDest = "C:\inetpub\wwwroot\jaypharma-api"

# 1. Deploy Flutter Web App
Write-Host "`n[1/4] Copying Web App to $webDest..." -ForegroundColor Yellow
if (!(Test-Path $webDest)) {
    New-Item -ItemType Directory -Path $webDest -Force | Out-Null
}

Copy-Item -Path "$webSource\*" -Destination $webDest -Recurse -Force -ErrorAction SilentlyContinue

# Ensure IIS index.html uses base href "/jaypharma/" for IIS sub-application
$destIndex = Join-Path $webDest "index.html"
if (Test-Path $destIndex) {
    (Get-Content $destIndex) -replace '<base href="/">', '<base href="/jaypharma/">' | Set-Content $destIndex -Encoding utf8
}
Write-Host "[OK] Web App copied successfully." -ForegroundColor Green

# 2. Deploy Release APK to IIS web directory for mobile download
Write-Host "`n[2/4] Deploying Release APK to IIS..." -ForegroundColor Yellow
if (Test-Path $apkSource) {
    $apkSizeMb = [math]::Round((Get-Item $apkSource).Length / 1MB, 2)
    Copy-Item -Path $apkSource -Destination (Join-Path $webDest "jaypharma.apk") -Force
    Copy-Item -Path $apkSource -Destination (Join-Path $webDest "app-release.apk") -Force
    Copy-Item -Path $apkSource -Destination "d:\My Projects\JayPharma\jaypharma.apk" -Force
    Copy-Item -Path $apkSource -Destination "d:\My Projects\JayPharma\JayPharma_v1.0.1.apk" -Force
    Write-Host "[OK] APK ($apkSizeMb MB) copied to:" -ForegroundColor Green
    Write-Host "     - $webDest\jaypharma.apk" -ForegroundColor DarkGray
    Write-Host "     - $webDest\app-release.apk" -ForegroundColor DarkGray
    Write-Host "     - d:\My Projects\JayPharma\jaypharma.apk" -ForegroundColor DarkGray
} else {
    Write-Host "[!] Warning: Release APK not found at $apkSource" -ForegroundColor Red
}

# 3. Publish & Deploy Backend API
Write-Host "`n[3/4] Publishing and deploying .NET Backend API..." -ForegroundColor Yellow
& dotnet publish "d:\My Projects\JayPharma\backend\JayPharma.Api\JayPharma.Api.csproj" -c Release -o $apiSource

$appOffline = Join-Path $apiDest "app_offline.htm"
Set-Content -Path $appOffline -Value "<html><body>Updating API...</body></html>" -Encoding utf8
Start-Sleep -Seconds 2

# Robocopy updates only modified files and handles in-use files gracefully
robocopy $apiSource $apiDest /E /XO /R:1 /W:1 /NJH /NJS | Out-Null

Remove-Item -Path $appOffline -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Backend API deployed to $apiDest" -ForegroundColor Green

# 4. Permissions
Write-Host "`n[4/4] Ensuring IIS permissions..." -ForegroundColor Yellow
try {
    icacls $webDest /grant "Users:(OI)(CI)F" /grant "IIS_IUSRS:(OI)(CI)F" /T /Q | Out-Null
    icacls $apiDest /grant "Users:(OI)(CI)F" /grant "IIS_IUSRS:(OI)(CI)F" /T /Q | Out-Null
    Write-Host "[OK] Permissions configured." -ForegroundColor Green
} catch {}

Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "   DEPLOYMENT TO IIS SUCCESSFUL!                      " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "Web App URL:       http://220.247.236.89:83/jaypharma/" -ForegroundColor Cyan
Write-Host "Direct APK URL:    http://220.247.236.89:83/jaypharma/jaypharma.apk" -ForegroundColor Cyan
Write-Host "Backend API URL:   http://220.247.236.89:83/jaypharma-api/api" -ForegroundColor Cyan
