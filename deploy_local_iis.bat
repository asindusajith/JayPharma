@echo off
:: Batch script to run deploy_local_iis.ps1 with Administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_local_iis.ps1"
) else (
    echo Requesting Administrator privileges to copy files to C:\inetpub\wwwroot...
    powershell.exe -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0deploy_local_iis.ps1\"\"' -Verb RunAs"
)
