$ErrorActionPreference = "Stop"

Write-Host "Preparando ElectroHogar Flutter..." -ForegroundColor Cyan

flutter create . --platforms=android --project-name electrohogar_mobile

Copy-Item ".\config\AndroidManifest.xml" ".\android\app\src\main\AndroidManifest.xml" -Force

flutter pub get

Write-Host ""
Write-Host "Flutter preparado correctamente." -ForegroundColor Green
Write-Host "Enciende Apache y MySQL en XAMPP." -ForegroundColor Yellow
Write-Host "Luego inicia un emulador Android y ejecuta:"
Write-Host "flutter run"
Write-Host ""
Write-Host "API para emulador:"
Write-Host "http://10.0.2.2/electrodomesticos/api"
