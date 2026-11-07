<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_role(['admin','vendedor']);
require_once __DIR__ . '/includes/layout.php';

$db = (new Database())->getConnection();
$esAdmin = es_admin();
$mensaje = $error = '';
$editar = null;

/* Crear el módulo automáticamente en bases existentes */
try {
    $db->exec("
        CREATE TABLE IF NOT EXISTS proveedores (
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
        ) ENGINE=InnoDB
    ");
} catch (Throwable $e) {
    $error = 'No se pudo preparar el módulo de proveedores: ' . $e->getMessage();
}

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!$esAdmin) {
            throw new Exception('Solo el administrador puede registrar o modificar proveedores.');
        }

        $accion = $_POST['accion'] ?? '';

        if ($accion === 'guardar') {
            $id = (int)($_POST['id'] ?? 0);
            $razonSocial = trim($_POST['razon_social'] ?? '');
            $ruc = trim($_POST['ruc'] ?? '');
            $contacto = trim($_POST['contacto'] ?? '');
            $telefono = trim($_POST['telefono'] ?? '');
            $email = trim($_POST['email'] ?? '');
            $direccion = trim($_POST['direccion'] ?? '');

            if ($razonSocial === '' || $ruc === '') {
                throw new Exception('Razón social y RUC son obligatorios.');
            }

            if (!preg_match('/^\d{11}$/', $ruc)) {
                throw new Exception('El RUC debe contener exactamente 11 números.');
            }

            if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                throw new Exception('El correo electrónico no es válido.');
            }

            if ($id > 0) {
                $s = $db->prepare("
                    UPDATE proveedores
                    SET razon_social=?, ruc=?, contacto=?, telefono=?, email=?, direccion=?
                    WHERE id=?
                ");
                $s->execute([
                    $razonSocial,
                    $ruc,
                    $contacto ?: null,
                    $telefono ?: null,
                    $email ?: null,
                    $direccion ?: null,
                    $id
                ]);
                $mensaje = 'Proveedor actualizado correctamente.';
            } else {
                $s = $db->prepare("
                    INSERT INTO proveedores(razon_social,ruc,contacto,telefono,email,direccion,estado)
                    VALUES(?,?,?,?,?,?,1)
                ");
                $s->execute([
                    $razonSocial,
                    $ruc,
                    $contacto ?: null,
                    $telefono ?: null,
                    $email ?: null,
                    $direccion ?: null
                ]);
                $mensaje = 'Proveedor registrado correctamente.';
            }
        }

        if ($accion === 'estado') {
            $id = (int)($_POST['id'] ?? 0);
            $estado = (int)($_POST['estado'] ?? 0) === 1 ? 1 : 0;

            $s = $db->prepare("UPDATE proveedores SET estado=? WHERE id=?");
            $s->execute([$estado,$id]);

            $mensaje = $estado === 1
                ? 'Proveedor activado correctamente.'
                : 'Proveedor desactivado correctamente.';
        }
    }
} catch (Throwable $e) {
    if (str_contains($e->getMessage(), 'Duplicate entry')) {
        $error = 'Ese RUC ya está registrado en otro proveedor.';
    } else {
        $error = $e->getMessage();
    }
}

if (isset($_GET['editar'])) {
    if (!$esAdmin) {
        http_response_code(403);
        die('Acceso denegado: solo el administrador puede editar proveedores.');
    }

    $s = $db->prepare("SELECT * FROM proveedores WHERE id=?");
    $s->execute([(int)$_GET['editar']]);
    $editar = $s->fetch();
}

$q = trim($_GET['q'] ?? '');

if ($q !== '') {
    $like = "%$q%";
    $s = $db->prepare("
        SELECT *
        FROM proveedores
        WHERE razon_social LIKE ?
           OR ruc LIKE ?
           OR contacto LIKE ?
           OR telefono LIKE ?
        ORDER BY estado DESC, razon_social
    ");
    $s->execute([$like,$like,$like,$like]);
    $proveedores = $s->fetchAll();
} else {
    $proveedores = $db->query("
        SELECT *
        FROM proveedores
        ORDER BY estado DESC, razon_social
    ")->fetchAll();
}

app_top('Proveedores','proveedores');
?>

<?php if($mensaje): ?>
<div class="alert alert-success"><?= htmlspecialchars($mensaje) ?></div>
<?php endif; ?>

<?php if($error): ?>
<div class="alert alert-error"><?= htmlspecialchars($error) ?></div>
<?php endif; ?>

<?php if($esAdmin): ?>
<section class="panel">
    <div class="panel-header">
        <div>
            <h3><?= $editar ? 'Editar proveedor' : 'Nuevo proveedor' ?></h3>
            <span class="muted">RF15 · Gestión de proveedores</span>
        </div>
    </div>

    <div class="panel-body">
        <form method="post">
            <input type="hidden" name="accion" value="guardar">
            <input type="hidden" name="id" value="<?= (int)($editar['id'] ?? 0) ?>">

            <div class="form-grid">
                <div>
                    <label>Razón social</label>
                    <input
                        name="razon_social"
                        required
                        maxlength="150"
                        value="<?= htmlspecialchars($editar['razon_social'] ?? '') ?>"
                        placeholder="Ej. Distribuidora Electro Perú SAC"
                    >
                </div>

                <div>
                    <label>RUC</label>
                    <input
                        name="ruc"
                        required
                        maxlength="11"
                        inputmode="numeric"
                        pattern="[0-9]{11}"
                        value="<?= htmlspecialchars($editar['ruc'] ?? '') ?>"
                        placeholder="Ej. 20123456789"
                    >
                </div>

                <div>
                    <label>Persona de contacto</label>
                    <input
                        name="contacto"
                        maxlength="120"
                        value="<?= htmlspecialchars($editar['contacto'] ?? '') ?>"
                        placeholder="Ej. José Ramírez"
                    >
                </div>

                <div>
                    <label>Teléfono</label>
                    <input
                        name="telefono"
                        maxlength="20"
                        value="<?= htmlspecialchars($editar['telefono'] ?? '') ?>"
                        placeholder="Ej. 999 888 777"
                    >
                </div>

                <div>
                    <label>Correo electrónico</label>
                    <input
                        type="email"
                        name="email"
                        maxlength="120"
                        value="<?= htmlspecialchars($editar['email'] ?? '') ?>"
                        placeholder="ventas@proveedor.com"
                    >
                </div>

                <div>
                    <label>Dirección</label>
                    <input
                        name="direccion"
                        maxlength="220"
                        value="<?= htmlspecialchars($editar['direccion'] ?? '') ?>"
                        placeholder="Dirección del proveedor"
                    >
                </div>

                <div class="full actions">
                    <button class="btn btn-primary" type="submit">💾 Guardar proveedor</button>
                    <?php if($editar): ?>
                        <a class="btn btn-secondary" href="proveedores.php">Cancelar</a>
                    <?php endif; ?>
                </div>
            </div>
        </form>
    </div>
</section>
<?php else: ?>
<div class="alert alert-info">
    Puedes consultar los proveedores registrados. Solo el administrador puede crearlos o modificarlos.
</div>
<?php endif; ?>

<div class="toolbar">
    <form class="search" method="get">
        <input
            name="q"
            value="<?= htmlspecialchars($q) ?>"
            placeholder="Buscar por razón social, RUC, contacto o teléfono"
        >
        <button class="btn btn-primary">🔎 Buscar</button>

        <?php if($q !== ''): ?>
            <a class="btn btn-secondary" href="proveedores.php">Limpiar</a>
        <?php endif; ?>
    </form>
</div>

<section class="panel">
    <div class="panel-header">
        <h3>Proveedores registrados</h3>
        <span class="muted"><?= count($proveedores) ?> proveedores</span>
    </div>

    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Proveedor</th>
                    <th>RUC</th>
                    <th>Contacto</th>
                    <th>Teléfono</th>
                    <th>Correo</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach($proveedores as $p): ?>
                <tr>
                    <td>#<?= (int)$p['id'] ?></td>
                    <td>
                        <strong><?= htmlspecialchars($p['razon_social']) ?></strong><br>
                        <small class="muted"><?= htmlspecialchars($p['direccion'] ?? '') ?></small>
                    </td>
                    <td><?= htmlspecialchars($p['ruc']) ?></td>
                    <td><?= htmlspecialchars($p['contacto'] ?: '-') ?></td>
                    <td><?= htmlspecialchars($p['telefono'] ?: '-') ?></td>
                    <td><?= htmlspecialchars($p['email'] ?: '-') ?></td>
                    <td>
                        <span class="badge <?= (int)$p['estado'] === 1 ? 'badge-green' : 'badge-red' ?>">
                            <?= (int)$p['estado'] === 1 ? 'Activo' : 'Inactivo' ?>
                        </span>
                    </td>
                    <td>
                        <?php if($esAdmin): ?>
                            <div class="actions">
                                <a class="btn btn-secondary" href="?editar=<?= $p['id'] ?>">✏️ Editar</a>

                                <form method="post" onsubmit="return confirm('¿Cambiar el estado de este proveedor?')">
                                    <input type="hidden" name="accion" value="estado">
                                    <input type="hidden" name="id" value="<?= $p['id'] ?>">
                                    <input type="hidden" name="estado" value="<?= (int)$p['estado'] === 1 ? 0 : 1 ?>">
                                    <button class="btn <?= (int)$p['estado'] === 1 ? 'btn-danger' : 'btn-success' ?>" type="submit">
                                        <?= (int)$p['estado'] === 1 ? '⛔ Desactivar' : '✅ Activar' ?>
                                    </button>
                                </form>
                            </div>
                        <?php else: ?>
                            <span class="badge badge-blue">Solo lectura</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if(!$proveedores): ?>
                <tr>
                    <td colspan="8" class="empty">No hay proveedores registrados.</td>
                </tr>
            <?php endif; ?>
            </tbody>
        </table>
    </div>
</section>

<?php app_bottom(); ?>