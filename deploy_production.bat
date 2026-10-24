@echo off
title Deploy Jay Pharma to IIS
echo ======================================================
echo    Deploying Jay Pharma (Web + APK + API) to IIS
echo ======================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_production.ps1"
pause
