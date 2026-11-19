<?php
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responder(false, "Método no permitido", null, 405);
}

$d = jsonInput();
foreach (['nombre', 'usuario', 'password', 'confirmacion'] as $campo) {
    if (!isset($d[$campo]) || !is_string($d[$campo])) {
        responder(false, "Completa todos los campos", null, 422);
    }
}
$nombre = trim($d['nombre']);
$usuario = trim($d['usuario']);
$password = $d['password'];
$largo = function_exists('mb_strlen') ? mb_strlen($nombre, 'UTF-8') : strlen($nombre);
if ($largo < 2 || $largo > 100) {
    responder(false, "Escribe un nombre de 2 a 100 caracteres", null, 422);
}
if (!preg_match('/^[A-Za-z0-9_.-]{4,50}$/D', $usuario)) {
    responder(false, "El usuario debe tener 4 a 50 letras, números, puntos, guiones o guiones bajos", null, 422);
}
if (strlen($password) < 8 || strlen($password) > 72 || strpos($password, chr(0)) !== false) {
    responder(false, "La contraseña debe tener entre 8 y 72 bytes", null, 422);
}
if ($password !== $d['confirmacion']) {
    responder(false, "Las contraseñas no coinciden", null, 422);
}
try {
    $db = (new Database())->getConnection();
    $hash = password_hash($password, PASSWORD_DEFAULT);
    $s = $db->prepare("INSERT INTO usuarios(nombre,usuario,password,rol,estado) VALUES(?,?,?,'cliente',1)");
    $s->execute([$nombre, $usuario, $hash]);
    responder(true, "Cuenta creada correctamente. Ya puedes iniciar sesión.", null, 201);
} catch (PDOException $e) {
    if ((string)$e->getCode() === '23000') {
        responder(false, "Ese nombre de usuario ya está registrado", null, 409);
    }
    responder(false, "No se pudo crear la cuenta. Revisa MySQL.", null, 500);
} catch (Throwable $e) {
    responder(false, "No se pudo crear la cuenta", null, 500);
}
