<?php
header("Content-Type: application/json; charset=UTF-8");
// Chrome Flutter (puerto 7357): permitir la sesion PHP solo desde orígenes locales autorizados.
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$localOrigins = ['http://localhost:7357', 'http://127.0.0.1:7357'];
if (in_array($origin, $localOrigins, true)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Credentials: true');
    header('Vary: Origin');
}
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit;
}

function jsonInput(): array {
    $raw = file_get_contents("php://input");
    $data = json_decode($raw ?: "[]", true);
    return is_array($data) ? $data : [];
}

function responder(bool $ok, string $mensaje, $data = null, int $status = 200): void {
    http_response_code($status);
    $resp = ["ok" => $ok, "mensaje" => $mensaje];
    if ($data !== null) $resp["data"] = $data;
    echo json_encode($resp, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

function requerido(array $data, array $campos): void {
    foreach ($campos as $campo) {
        if (!isset($data[$campo]) || trim((string)$data[$campo]) === "") {
            responder(false, "El campo '$campo' es obligatorio", null, 422);
        }
    }
}
?>