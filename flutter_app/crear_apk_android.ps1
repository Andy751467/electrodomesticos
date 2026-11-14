# Generar APK Android de prueba, sin emulador.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "ELECTROHOGAR - GENERAR APK ANDROID" -ForegroundColor Cyan
$setup = Join-Path $PSScriptRoot "setup.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup
if ($LASTEXITCODE -ne 0) { throw "No se pudo configurar Android." }

$cmd = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($cmd) { $cmd.Source } else { $null }
if (!$flutter) {
    $candidates = @(
        (Join-Path $env:USERPROFILE "Downloads\APLICACIONES MOVILES\partgo_work\flutter\bin\flutter.bat"),
        "C:\src\flutter\bin\flutter.bat",
        (Join-Path $env:USERPROFILE "develop\flutter\bin\flutter.bat")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { $flutter = $candidate; break }
    }
}
if (!$flutter) { throw "No se encontro flutter.bat." }

Write-Host "Compilando APK de prueba..." -ForegroundColor Cyan
& $flutter build apk --debug
if ($LASTEXITCODE -ne 0) {
    throw "Error al generar APK. Si falta Android SDK, usa la compilacion automatica en GitHub Actions."
}

$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-debug.apk"
if (!(Test-Path $apk)) { throw "La compilacion no produjo un archivo APK." }

$salida = Join-Path $env:USERPROFILE "Downloads\ElectroHogar-Android.apk"
Copy-Item $apk $salida -Force
Write-Host "APK CREADO: $salida" -ForegroundColor Green
Write-Host "Copia este archivo al celular Samsung para instalarlo."
