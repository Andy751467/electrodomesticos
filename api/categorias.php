<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../config/auth.php';

if (!esta_logueado()) {
    responder(false, 'Debes iniciar sesión', null, 401);
}
$metodo = $_SERVER['REQUEST_METHOD'];
if (!in_array($metodo, ['GET', 'POST', 'PUT', 'DELETE'], true)) {
    responder(false, 'Método no permitido', null, 405);
}
if ($metodo !== 'GET' && !es_admin()) {
    responder(false, 'Solo el administrador puede gestionar categorías', null, 403);
}
if ($metodo !== 'GET' &&
    stripos($_SERVER['CONTENT_TYPE'] ?? '', 'application/json') !== 0) {
    responder(false, 'Se requiere una petición JSON', null, 415);
}

function idCategoria($valor): int {
    if (!is_scalar($valor) ||
        !preg_match('/^[1-9][0-9]*$/D', (string)$valor) ||
        (int)$valor <= 0) {
        responder(false, 'Identificador de categoría inválido', null, 422);
    }
    return (int)$valor;
}

function datosCategoria(array $datos): array {
    $nombre = $datos['nombre'] ?? null;
    $descripcion = $datos['descripcion'] ?? null;

    if (!is_string($nombre) || trim($nombre) === '') {
        responder(false, 'El nombre de la categoría es obligatorio', null, 422);
    }
    $nombre = trim($nombre);
    $largoNombre = function_exists('mb_strlen')
        ? mb_strlen($nombre, 'UTF-8') : strlen($nombre);
    if ($largoNombre > 100) {
        responder(false, 'El nombre admite hasta 100 caracteres', null, 422);
    }

    if ($descripcion !== null && !is_string($descripcion)) {
        responder(false, 'La descripción debe ser texto', null, 422);
    }
    $descripcion = is_string($descripcion) ? trim($descripcion) : null;
    if ($descripcion === '') $descripcion = null;
    $largoDescripcion = function_exists('mb_strlen')
        ? mb_strlen($descripcion ?? '', 'UTF-8')
        : strlen($descripcion ?? '');
    if ($largoDescripcion > 255) {
        responder(false, 'La descripción admite hasta 255 caracteres', null, 422);
    }
    return [$nombre, $descripcion];
}

try {
    $db = (new Database())->getConnection();

    if ($metodo === 'GET') {
        if (isset($_GET['id'])) {
            $id = idCategoria($_GET['id']);
            $consulta = $db->prepare(
                'SELECT c.id,c.nombre,c.descripcion,c.creado_en,
                        COUNT(p.id) AS total_productos
                 FROM categorias c
                 LEFT JOIN productos p ON p.categoria_id=c.id
                 WHERE c.id=?
                 GROUP BY c.id,c.nombre,c.descripcion,c.creado_en'
            );
            $consulta->execute([$id]);
            $categoria = $consulta->fetch();
            if (!$categoria) responder(false, 'Categoría no encontrada', null, 404);
            responder(true, 'Categoría encontrada', $categoria);
        }

        $categorias = $db->query(
            'SELECT c.id,c.nombre,c.descripcion,c.creado_en,
                    COUNT(p.id) AS total_productos
             FROM categorias c
             LEFT JOIN productos p ON p.categoria_id=c.id
             GROUP BY c.id,c.nombre,c.descripcion,c.creado_en
             ORDER BY c.nombre'
        )->fetchAll();
        responder(true, 'Lista de categorías', $categorias);
    }

    $datos = jsonInput();

    if ($metodo === 'POST') {
        [$nombre, $descripcion] = datosCategoria($datos);
        $consulta = $db->prepare(
            'INSERT INTO categorias(nombre,descripcion) VALUES(?,?)'
        );
        $consulta->execute([$nombre, $descripcion]);
        responder(true, 'Categoría registrada correctamente',
            ['id' => (int)$db->lastInsertId()], 201);
    }

    if ($metodo === 'PUT') {
        $id = idCategoria($datos['id'] ?? null);
        [$nombre, $descripcion] = datosCategoria($datos);

        $consulta = $db->prepare('UPDATE categorias SET nombre=?,descripcion=? WHERE id=?');
        $consulta->execute([$nombre, $descripcion, $id]);
        if ($consulta->rowCount() === 0) {
            $existe = $db->prepare('SELECT id FROM categorias WHERE id=?');
            $existe->execute([$id]);
            if (!$existe->fetchColumn()) {
                responder(false, 'Categoría no encontrada', null, 404);
            }
        }
        responder(true, 'Categoría actualizada correctamente');
    }

    $id = idCategoria($datos['id'] ?? null);
    $existe = $db->prepare('SELECT id FROM categorias WHERE id=?');
    $existe->execute([$id]);
    if (!$existe->fetchColumn()) {
        responder(false, 'Categoría no encontrada', null, 404);
    }
    $cuantos = $db->prepare('SELECT COUNT(*) FROM productos WHERE categoria_id=?');
    $cuantos->execute([$id]);
    if ((int)$cuantos->fetchColumn() > 0) {
        responder(false, 'No puedes eliminar esta categoría porque contiene productos. Reasigna primero los productos.', null, 409);
    }
    $eliminar = $db->prepare('DELETE FROM categorias WHERE id=?');
    $eliminar->execute([$id]);
    responder(true, 'Categoría eliminada correctamente');
} catch (PDOException $e) {
    if ((string)$e->getCode() === '23000') {
        if ($metodo === 'DELETE') {
            responder(false, 'No se puede eliminar: la categoría tiene productos asociados', null, 409);
        }
        responder(false, 'Ya existe una categoría con ese nombre', null, 409);
    }
    responder(false, 'No se pudo gestionar la categoría. Revisa MySQL.', null, 500);
}
