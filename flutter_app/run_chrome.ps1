# Ejecuta ElectroHogar Flutter en Google Chrome, sin Android Studio.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$localFlutter = Join-Path $env:USERPROFILE 'Downloads\APLICACIONES MOVILES\partgo_work\flutter\bin\flutter.bat'
$knownFlutter = @(
    $localFlutter,
    'C:\src\flutter\bin\flutter.bat',
    (Join-Path $env:USERPROFILE 'develop\flutter\bin\flutter.bat')
)
$flutterExe = $null
foreach ($f in $knownFlutter) {
    if (Test-Path $f) { $flutterExe = $f; break }
}
if (-not $flutterExe) {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { $flutterExe = $cmd.Source }
}
if (-not $flutterExe) { throw 'No se encontro Flutter. Revisa donde esta flutter.bat.' }

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'api\login.php'))) {
    $root = 'C:\xampp\htdocs\electrohogar_profesor'
}
if (-not (Test-Path (Join-Path $root 'api\login.php'))) {
    throw 'No se encontro el backend PHP. Copia flutter_app dentro de la carpeta ElectroHogar en C:\xampp\htdocs.'
}

# Configurar CORS local sin eliminar las demas funciones del backend.
$helpers = Join-Path $root 'config\helpers.php'
if (-not (Test-Path $helpers)) { throw 'Falta config\helpers.php del backend.' }
$txt = [System.IO.File]::ReadAllText($helpers)
$old = 'header("Access-Control-Allow-Origin: *");'
$new = @'
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed = ['http://localhost:7357', 'http://127.0.0.1:7357'];
if (in_array($origin, $allowed, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Credentials: true');
    header('Vary: Origin');
}
'@
if ($txt.Contains($old)) {
    Copy-Item $helpers ($helpers + '.copia_antes_flutter') -Force
    $txt = $txt.Replace($old, $new)
    [System.IO.File]::WriteAllText($helpers, $txt, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Conexion PHP preparada para Chrome. Se guardo copia del archivo anterior.' -ForegroundColor Green
}

$folder = Split-Path $root -Leaf
$apiUrl = "http://localhost/$folder/api"
Write-Host "API: $apiUrl" -ForegroundColor Cyan
Write-Host 'Enciende Apache y MySQL desde XAMPP.' -ForegroundColor Yellow

& $flutterExe config --enable-web
if ($LASTEXITCODE -ne 0) { throw 'Fallo flutter config.' }

& $flutterExe create . --platforms=web --project-name electrohogar_mobile
if ($LASTEXITCODE -ne 0) { throw 'Fallo flutter create.' }

& $flutterExe pub get
if ($LASTEXITCODE -ne 0) { throw 'Fallo flutter pub get.' }

& $flutterExe run -d chrome --web-hostname localhost --web-port 7357 "--dart-define=API_URL=$apiUrl"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo ejecutar Chrome. Revisa el error de Flutter.' }
