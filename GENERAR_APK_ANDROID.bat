@echo off
title ElectroHogar - Aplicacion Android
cd /d "%~dp0"
echo Preparando la aplicacion Android ElectroHogar...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0flutter_app\crear_apk_android.ps1"
if errorlevel 1 (
  echo.
  echo ERROR: Revisa el mensaje de compilacion en la pantalla.
  echo Alternativa: GitHub Actions puede compilar el APK en la nube.
)
pause
