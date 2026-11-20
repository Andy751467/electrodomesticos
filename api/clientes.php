<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../config/auth.php';

if (!esta_logueado()) {
    responder(false, 'Debes iniciar sesión', null, 401);
}
if (!in_array(rol_actual(), ['admin', 'vendedor'], true)) {
    responder(false, 'No tienes permiso para gestionar clientes', null, 403);
}

$method = $_SERVER['REQUEST_METHOD'];
if (!in_array($method, ['GET', 'POST', 'PUT', 'DELETE'], true)) {
    responder(false, 'Método no permitido', null, 405);
}
if ($method !== 'GET' &&
    stripos($_SERVER['CONTENT_TYPE'] ?? '', 'application/json') !== 0) {
    responder(false, 'Se requiere una petición JSON', null, 415);
}

$db = (new Database())->getConnection();

function idCliente($value): int {
    if (!is_numeric($value) || (string)(int)$value !== (string)$value || (int)$value <= 0) {
        responder(false, 'Identificador de cliente inválido', null, 422);
    }
    return (int)$value;
}

function textoCliente($value, string $campo, int $max, bool $obligatorio = false): ?string {
    if ($value === null) {
        if ($obligatorio) responder(false, "El campo $campo es obligatorio", null, 422);
        return null;
    }
    if (!is_string($value)) {
        responder(false, "El campo $campo debe ser texto", null, 422);
    }
    $valor = trim($value);
    if ($valor === '') {
        if ($obligatorio) responder(false, "El campo $campo es obligatorio", null, 422);
        return null;
    }
    $largo = function_exists('mb_strlen') ? mb_strlen($valor, 'UTF-8') : strlen($valor);
    if ($largo > $max) {
        responder(false, "El campo $campo supera los $max caracteres", null, 422);
    }
    return $valor;
}

function datosCliente(array $d): array {
    $nombres = textoCliente($d['nombres'] ?? null, 'nombres', 100, true);
    $apellidos = textoCliente($d['apellidos'] ?? null, 'apellidos', 100);
    $dni = textoCliente($d['dni'] ?? null, 'DNI', 15);
    $telefono = textoCliente($d['telefono'] ?? null, 'teléfono', 20);
    $email = textoCliente($d['email'] ?? null, 'correo', 120);
    $direccion = textoCliente($d['direccion'] ?? null, 'dirección', 200);

    if ($dni !== null && !preg_match('/^[0-9]{8}$/D', $dni)) {
        responder(false, 'El DNI debe tener 8 dígitos', null, 422);
    }
    if ($email !== null && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        responder(false, 'El correo electrónico no es válido', null, 422);
    }
    return [$nombres, $apellidos, $dni, $telefono, $email, $direccion];
}

try {
    if ($method === 'GET') {
        if (isset($_GET['id'])) {
            $id = idCliente($_GET['id']);
            $s = $db->prepare(
                'SELECT id,nombres,apellidos,dni,telefono,email,direccion,creado_en FROM clientes WHERE id=?'
            );
            $s->execute([$id]);
            $cliente = $s->fetch();
            if (!$cliente) responder(false, 'Cliente no encontrado', null, 404);
            responder(true, 'Cliente encontrado', $cliente);
        }
        $clientes = $db->query(
            'SELECT id,nombres,apellidos,dni,telefono,email,direccion,creado_en FROM clientes ORDER BY id DESC'
        )->fetchAll();
        responder(true, 'Lista de clientes', $clientes);
    }

    $d = jsonInput();
    if ($method === 'POST') {
        $datos = datosCliente($d);
        $s = $db->prepare(
            'INSERT INTO clientes(nombres,apellidos,dni,telefono,email,direccion) VALUES(?,?,?,?,?,?)'
        );
        $s->execute($datos);
        responder(true, 'Cliente registrado correctamente', ['id' => (int)$db->lastInsertId()], 201);
    }

    if ($method === 'PUT') {
        $id = idCliente($d['id'] ?? null);
        $datos = datosCliente($d);
        $existe = $db->prepare('SELECT id FROM clientes WHERE id=?');
        $existe->execute([$id]);
        if (!$existe->fetchColumn()) responder(false, 'Cliente no encontrado', null, 404);

        $s = $db->prepare(
            'UPDATE clientes SET nombres=?,apellidos=?,dni=?,telefono=?,email=?,direccion=? WHERE id=?'
        );
        $s->execute([...$datos, $id]);
        responder(true, 'Cliente actualizado correctamente');
    }

    if (!es_admin()) {
        responder(false, 'Solo el administrador puede eliminar clientes', null, 403);
    }
    $id = idCliente($d['id'] ?? null);
    $existe = $db->prepare('SELECT id FROM clientes WHERE id=?');
    $existe->execute([$id]);
    if (!$existe->fetchColumn()) responder(false, 'Cliente no encontrado', null, 404);

    $ventas = $db->prepare('SELECT COUNT(*) FROM ventas WHERE cliente_id=?');
    $ventas->execute([$id]);
    if ((int)$ventas->fetchColumn() > 0) {
        responder(false, 'No se puede eliminar: el cliente tiene ventas registradas', null, 409);
    }

    $s = $db->prepare('DELETE FROM clientes WHERE id=?');
    $s->execute([$id]);
    responder(true, 'Cliente eliminado correctamente');
} catch (PDOException $e) {
    if ($e->getCode() === '23000') {
        if ($method === 'DELETE') {
            responder(false, 'No se puede eliminar: el cliente tiene registros relacionados', null, 409);
        }
        responder(false, 'El DNI ya está registrado o existe un dato duplicado', null, 409);
    }
    responder(false, 'Error al gestionar clientes. Revisa MySQL.', null, 500);
}
