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

function rol_actual(): string {
    return $_SESSION['usuario']['rol'] ?? '';
}

function es_admin(): bool {
    return rol_actual() === 'admin';
}

function es_vendedor(): bool {
    return rol_actual() === 'vendedor';
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

    if (!in_array(rol_actual(), $roles, true)) {
        http_response_code(403);
        echo '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Acceso denegado</title></head>';
        echo '<body style="font-family:Segoe UI,Arial,sans-serif;background:#f3f4f6;padding:40px">';
        echo '<div style="max-width:600px;margin:auto;background:white;border:1px solid #e5e7eb;border-radius:14px;padding:24px">';
        echo '<h2 style="color:#b91c1c">Acceso denegado</h2>';
        echo '<p>No tienes permiso para acceder a esta sección.</p>';
        echo '<p><a href="dashboard.php">Volver al dashboard</a></p>';
        echo '</div></body></html>';
        exit;
    }
}
?>