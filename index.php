<?php
require_once __DIR__ . '/config/database.php';

try {
    $db = (new Database())->getConnection();
    $db->query("SELECT 1 FROM productos LIMIT 1");
    header("Location: dashboard.php");
    exit;
} catch (Throwable $e) {
    header("Location: install.php");
    exit;
}
?>