# Prepara ElectroHogar Android sin abrir un emulador.
# Para compilar en Windows hace falta Flutter, Java y Android SDK.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) { $flutterCommand.Source } else { $null }
if (!$flutter) {
    $known = @(
        (Join-Path $env:USERPROFILE "Downloads\APLICACIONES MOVILES\partgo_work\flutter\bin\flutter.bat"),
        "C:\src\flutter\bin\flutter.bat",
        (Join-Path $env:USERPROFILE "develop\flutter\bin\flutter.bat")
    )
    foreach ($item in $known) {
        if (Test-Path $item) {
            $flutter = $item
            break
        }
    }
}
if (!$flutter) { throw "Flutter no esta instalado o no esta en PATH." }

Write-Host "Preparando aplicacion Android de ElectroHogar..." -ForegroundColor Cyan
& $flutter create --platforms=android --org com.electrohogar --project-name electrohogar_mobile .
if ($LASTEXITCODE -ne 0) { throw "Error creando la plataforma Android." }

$manifest = Join-Path $PSScriptRoot "config\AndroidManifest.xml"
$targetManifest = Join-Path $PSScriptRoot "android\app\src\main\AndroidManifest.xml"
if (!(Test-Path $manifest)) { throw "Falta config\AndroidManifest.xml." }
Copy-Item $manifest $targetManifest -Force

& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw "No se pudieron instalar las dependencias Flutter." }

Write-Host ""
Write-Host "Proyecto Android preparado." -ForegroundColor Green
Write-Host "Para generar el APK de prueba ejecuta:" -ForegroundColor Yellow
Write-Host 'powershell -NoProfile -ExecutionPolicy Bypass -File ".\crear_apk_android.ps1"'
Write-Host "No necesitas un emulador. Si falta Android SDK usa el compilador en GitHub Actions."
