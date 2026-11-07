$ErrorActionPreference = "Stop"

Write-Host "Preparando ElectroHogar Flutter..." -ForegroundColor Cyan

$temp = Join-Path $env:TEMP "electrohogar_flutter_setup"
New-Item -ItemType Directory -Force -Path $temp | Out-Null

Copy-Item ".\lib\main.dart" (Join-Path $temp "main.dart") -Force
Copy-Item ".\pubspec.yaml" (Join-Path $temp "pubspec.yaml") -Force

flutter create . --platforms=android --project-name electrohogar_mobile

Copy-Item (Join-Path $temp "main.dart") ".\lib\main.dart" -Force
Copy-Item (Join-Path $temp "pubspec.yaml") ".\pubspec.yaml" -Force
Copy-Item ".\config\AndroidManifest.xml" ".\android\app\src\main\AndroidManifest.xml" -Force

flutter pub get

Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Flutter preparado correctamente." -ForegroundColor Green
Write-Host "Enciende Apache y MySQL en XAMPP." -ForegroundColor Yellow
Write-Host "Luego inicia un emulador Android y ejecuta:"
Write-Host "flutter run"
Write-Host ""
Write-Host "API para emulador:"
Write-Host "http://10.0.2.2/electrodomesticos/api"
