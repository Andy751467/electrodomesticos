<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../config/auth.php';

if (!esta_logueado()) {
    responder(false, 'Debes iniciar sesión', null, 401);
}
if (!in_array(rol_actual(), ['admin', 'vendedor'], true)) {
    responder(false, 'No tienes permiso para consultar proveedores', null, 403);
}

$metodo = $_SERVER['REQUEST_METHOD'];
if (!in_array($metodo, ['GET', 'POST', 'PUT', 'DELETE'], true)) {
    responder(false, 'Método no permitido', null, 405);
}
if ($metodo !== 'GET' && !es_admin()) {
    responder(false, 'Solo el administrador puede gestionar proveedores', null, 403);
}
if ($metodo !== 'GET' &&
    stripos($_SERVER['CONTENT_TYPE'] ?? '', 'application/json') !== 0) {
    responder(false, 'Se requiere una petición JSON', null, 415);
}

function idProveedor($valor): int {
    if (!is_scalar($valor) ||
        !preg_match('/^[1-9][0-9]*$/D', (string)$valor) ||
        (int)$valor <= 0) {
        responder(false, 'Identificador de proveedor inválido', null, 422);
    }
    return (int)$valor;
}

function campoProveedor($valor, string $etiqueta, int $max, bool $obligatorio = false): ?string {
    if ($valor !== null && !is_string($valor)) {
        responder(false, "$etiqueta debe ser texto", null, 422);
    }
    $texto = trim($valor ?? '');
    if ($texto === '') {
        if ($obligatorio) responder(false, "El campo $etiqueta es obligatorio", null, 422);
        return null;
    }
    $largo = function_exists('mb_strlen')
        ? mb_strlen($texto, 'UTF-8') : strlen($texto);
    if ($largo > $max) {
        responder(false, "El campo $etiqueta admite hasta $max caracteres", null, 422);
    }
    return $texto;
}

function datosProveedor(array $datos): array {
    $razon = campoProveedor($datos['razon_social'] ?? null, 'razón social', 150, true);
    $ruc = campoProveedor($datos['ruc'] ?? null, 'RUC', 11, true);
    $contacto = campoProveedor($datos['contacto'] ?? null, 'contacto', 120);
    $telefono = campoProveedor($datos['telefono'] ?? null, 'teléfono', 20);
    $correo = campoProveedor($datos['email'] ?? null, 'correo', 120);
    $direccion = campoProveedor($datos['direccion'] ?? null, 'dirección', 220);
    if (!preg_match('/^[0-9]{11}$/D', $ruc)) {
        responder(false, 'El RUC debe contener exactamente 11 dígitos', null, 422);
    }
    if ($correo !== null && !filter_var($correo, FILTER_VALIDATE_EMAIL)) {
        responder(false, 'El correo electrónico no es válido', null, 422);
    }
    return [$razon, $ruc, $contacto, $telefono, $correo, $direccion];
}

try {
    $db = (new Database())->getConnection();

    // Mantener compatibilidad con instalaciones que aún no tienen la tabla.
    $db->exec(
        "CREATE TABLE IF NOT EXISTS proveedores (
            id INT AUTO_INCREMENT PRIMARY KEY,
            razon_social VARCHAR(150) NOT NULL,
            ruc VARCHAR(11) NOT NULL UNIQUE,
            contacto VARCHAR(120) NULL,
            telefono VARCHAR(20) NULL,
            email VARCHAR(120) NULL,
            direccion VARCHAR(220) NULL,
            estado TINYINT(1) NOT NULL DEFAULT 1,
            creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_proveedor_nombre (razon_social),
            INDEX idx_proveedor_estado (estado)
        ) ENGINE=InnoDB"
    );

    if ($metodo === 'GET') {
        if (isset($_GET['id'])) {
            $id = idProveedor($_GET['id']);
            $s = $db->prepare(
                'SELECT id,razon_social,ruc,contacto,telefono,email,direccion,estado,creado_en
                 FROM proveedores WHERE id=?'
            );
            $s->execute([$id]);
            $fila = $s->fetch();
            if (!$fila) responder(false, 'Proveedor no encontrado', null, 404);
            responder(true, 'Proveedor encontrado', $fila);
        }

        $q = $_GET['q'] ?? '';
        if (!is_string($q)) responder(false, 'Búsqueda inválida', null, 422);
        $q = trim($q);
        if (strlen($q) > 120) responder(false, 'La búsqueda es demasiado larga', null, 422);
        if ($q !== '') {
            $like = "%$q%";
            $s = $db->prepare(
                'SELECT id,razon_social,ruc,contacto,telefono,email,direccion,estado,creado_en
                 FROM proveedores
                 WHERE razon_social LIKE ? OR ruc LIKE ? OR contacto LIKE ? OR telefono LIKE ?
                 ORDER BY estado DESC, razon_social'
            );
            $s->execute([$like, $like, $like, $like]);
            responder(true, 'Resultados de búsqueda', $s->fetchAll());
        }
        $filas = $db->query(
            'SELECT id,razon_social,ruc,contacto,telefono,email,direccion,estado,creado_en
             FROM proveedores ORDER BY estado DESC, razon_social'
        )->fetchAll();
        responder(true, 'Lista de proveedores', $filas);
    }

    $datos = jsonInput();

    if ($metodo === 'POST') {
        $campos = datosProveedor($datos);
        $s = $db->prepare(
            'INSERT INTO proveedores(razon_social,ruc,contacto,telefono,email,direccion,estado)
             VALUES(?,?,?,?,?,?,1)'
        );
        $s->execute($campos);
        responder(true, 'Proveedor registrado correctamente',
            ['id' => (int)$db->lastInsertId()], 201);
    }

    if ($metodo === 'PUT') {
        $id = idProveedor($datos['id'] ?? null);
        $campos = datosProveedor($datos);
        $estado = $datos['estado'] ?? 1;
        if ($estado !== 0 && $estado !== 1) {
            responder(false, 'El estado debe ser activo o inactivo', null, 422);
        }
        $exists = $db->prepare('SELECT id FROM proveedores WHERE id=?');
        $exists->execute([$id]);
        if (!$exists->fetchColumn()) {
            responder(false, 'Proveedor no encontrado', null, 404);
        }
        $s = $db->prepare(
            'UPDATE proveedores
             SET razon_social=?,ruc=?,contacto=?,telefono=?,email=?,direccion=?,estado=?
             WHERE id=?'
        );
        $s->execute([...$campos, $estado, $id]);
        responder(true, 'Proveedor actualizado correctamente');
    }

    // DELETE significa desactivar; no se destruyen datos de proveedores.
    $id = idProveedor($datos['id'] ?? null);
    $exists = $db->prepare('SELECT id FROM proveedores WHERE id=?');
    $exists->execute([$id]);
    if (!$exists->fetchColumn()) {
        responder(false, 'Proveedor no encontrado', null, 404);
    }
    $s = $db->prepare('UPDATE proveedores SET estado=0 WHERE id=?');
    $s->execute([$id]);
    responder(true, 'Proveedor desactivado. Puedes reactivarlo desde Editar.');
} catch (PDOException $e) {
    if ((string)$e->getCode() === '23000') {
        responder(false, 'Este RUC ya está registrado en otro proveedor', null, 409);
    }
    responder(false, 'No se pudieron gestionar los proveedores. Revisa MySQL.', null, 500);
}
