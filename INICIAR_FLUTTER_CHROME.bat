@echo off
title ElectroHogar - Flutter Web en Google Chrome
cd /d "%~dp0"
echo ============================================
echo  ELECTROHOGAR - FLUTTER WEB CON LOCALHOST
echo ============================================
echo.
echo Requisito: Apache y MySQL encendidos en XAMPP.
echo No se necesita Android Studio ni emulador.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0flutter_app\run_chrome.ps1"
echo.
if errorlevel 1 (
  echo Ocurrio un error. Revisa el mensaje y envia una captura.
)
pause
