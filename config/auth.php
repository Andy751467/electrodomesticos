<?php
if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

function usuario_actual(): ?array {
    return $_SESSION['usuario'] ?? null;
}

function esta_logueado(): bool {
    return isset($_SESSION['usuario']['id']);
}

function require_login(): void {
    if (!esta_logueado()) {
        $destino = basename($_SERVER['REQUEST_URI'] ?? 'dashboard.php');
        header('Location: login.php?next=' . urlencode($destino));
        exit;
    }
}

function require_role(array $roles): void {
    require_login();
    $rol = $_SESSION['usuario']['rol'] ?? '';
    if (!in_array($rol, $roles, true)) {
        http_response_code(403);
        echo '<h2>Acceso denegado</h2><p>No tienes permiso para acceder a esta sección.</p>';
        exit;
    }
}
?>