<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';

try {
    $db = (new Database())->getConnection();
    $db->query("SELECT 1 FROM usuarios LIMIT 1");

    if (esta_logueado()) {
        header("Location: dashboard.php");
    } else {
        header("Location: login.php");
    }
    exit;

} catch (Throwable $e) {
    header("Location: install.php");
    exit;
}
?>