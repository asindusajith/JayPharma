# ====================================================================
# JAY PHARMA - Automatic IIS Local Deployment Script
# ====================================================================

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  JAY PHARMA - IIS LOCAL DEPLOYMENT (PORT 83)        " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceWeb = Join-Path $scriptDir "build\web"
$destWeb = "C:\inetpub\wwwroot\jaypharma"

$sourceApi = Join-Path $scriptDir "publish"
$destApi = "C:\inetpub\wwwroot\jaypharma-api"

# 1. Deploy Flutter Web App
if (!(Test-Path $destWeb)) {
    New-Item -ItemType Directory -Path $destWeb -Force | Out-Null
}

Write-Host "`n[1/3] Copying Flutter Web App to IIS wwwroot..." -ForegroundColor Yellow
Copy-Item -Path "$sourceWeb\*" -Destination $destWeb -Recurse -Force
Write-Host "[OK] Jay Pharma Web App deployed to: $destWeb" -ForegroundColor Green

# 2. Deploy .NET Backend API (if publish exists)
if (Test-Path $sourceApi) {
    Write-Host "`n[2/3] Deploying .NET Core API files..." -ForegroundColor Yellow
    if (!(Test-Path $destApi)) {
        New-Item -ItemType Directory -Path $destApi -Force | Out-Null
    }
    # Write OutOfProcess web.config to publish folder (without location path, required for IIS sub-application)
    $outOfProcessConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath="dotnet" arguments=".\JayPharma.Api.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="OutOfProcess" />
  </system.webServer>
</configuration>
"@
    Set-Content -Path (Join-Path $sourceApi "web.config") -Value $outOfProcessConfig -Encoding utf8

    # Put app_offline.htm into IIS folder to release file locks
    "<html><body>Updating API...</body></html>" | Out-File (Join-Path $destApi "app_offline.htm") -Encoding utf8 -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800

    try {
        Copy-Item -Path "$sourceApi\*" -Destination $destApi -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $destApi "app_offline.htm") -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Jay Pharma API copied to: $destApi" -ForegroundColor Green
    } catch {
        Write-Host "[!] Note on API copy: $_" -ForegroundColor DarkGray
    }

    # Register JayPharmaApiPool and Application in IIS
    $appcmd = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
    if (Test-Path $appcmd) {
        try {
            & $appcmd add apppool /name:JayPharmaApiPool /managedRuntimeVersion:"" *>$null
        } catch {}
        try {
            & $appcmd set apppool "JayPharmaApiPool" /managedRuntimeVersion:"" *>$null
        } catch {}
        try {
            & $appcmd add app /site.name:"Default Web Site" /path:"/jaypharma-api" /physicalPath:"$destApi" /applicationPool:JayPharmaApiPool *>$null
        } catch {}
        try {
            & $appcmd set app "Default Web Site/jaypharma-api" /applicationPool:JayPharmaApiPool *>$null
        } catch {}
    }
}

# 3. Grant Permissions for IIS and Users
Write-Host "`n[3/3] Setting directory permissions..." -ForegroundColor Yellow
try {
    icacls $destWeb /grant "Users:(OI)(CI)F" /grant "IIS_IUSRS:(OI)(CI)F" /T /Q | Out-Null
    icacls $destApi /grant "Users:(OI)(CI)F" /grant "IIS_IUSRS:(OI)(CI)F" /T /Q | Out-Null
    Write-Host "[OK] Permissions configured successfully." -ForegroundColor Green
} catch {
    Write-Host "[!] Note on permissions: $_" -ForegroundColor DarkGray
}

# Check Backend API running on port 5100
$apiRunning = $false
try {
    $res = Invoke-RestMethod -Uri "http://localhost:5100/api/users" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($res) { $apiRunning = $true }
} catch {}

if (!$apiRunning) {
    Write-Host "`n[*] Starting Jay Pharma Backend API on port 5100..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -Command `"cd '$scriptDir'; dotnet run --project backend/JayPharma.Api/JayPharma.Api.csproj --urls 'http://0.0.0.0:5100' `"" -WindowStyle Minimized
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETED SUCCESSFULLY!                  " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "Local IIS Web URL:   http://localhost:83/jaypharma/" -ForegroundColor Yellow
Write-Host "Backend API URL:     http://localhost:5100/api" -ForegroundColor Yellow
Write-Host ""
Start-Process "http://localhost:83/jaypharma/"

Read-Host "Press Enter to exit..."
