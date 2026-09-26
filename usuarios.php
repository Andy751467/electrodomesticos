<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_role(['admin']);
require_once __DIR__ . '/includes/layout.php';

$db = (new Database())->getConnection();
$mensaje = $error = '';
$editar = null;

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $accion = $_POST['accion'] ?? '';

        if ($accion === 'guardar') {
            $id = (int)($_POST['id'] ?? 0);
            $nombre = trim($_POST['nombre'] ?? '');
            $usuario = trim($_POST['usuario'] ?? '');
            $rol = $_POST['rol'] ?? 'vendedor';
            $estado = isset($_POST['estado']) ? 1 : 0;
            $password = (string)($_POST['password'] ?? '');

            if ($nombre === '' || $usuario === '') {
                throw new Exception('Nombre y usuario son obligatorios.');
            }

            if (!in_array($rol, ['admin','vendedor','cliente'], true)) {
                throw new Exception('Rol inválido.');
            }

            if ($id > 0) {
                if ($password !== '') {
                    if (strlen($password) < 6) {
                        throw new Exception('La contraseña debe tener por lo menos 6 caracteres.');
                    }

                    $hash = password_hash($password, PASSWORD_DEFAULT);
                    $s = $db->prepare("
                        UPDATE usuarios
                        SET nombre=?, usuario=?, password=?, rol=?, estado=?
                        WHERE id=?
                    ");
                    $s->execute([$nombre,$usuario,$hash,$rol,$estado,$id]);
                } else {
                    $s = $db->prepare("
                        UPDATE usuarios
                        SET nombre=?, usuario=?, rol=?, estado=?
                        WHERE id=?
                    ");
                    $s->execute([$nombre,$usuario,$rol,$estado,$id]);
                }

                $mensaje = 'Usuario actualizado correctamente.';
            } else {
                if (strlen($password) < 6) {
                    throw new Exception('La contraseña debe tener por lo menos 6 caracteres.');
                }

                $hash = password_hash($password, PASSWORD_DEFAULT);

                $s = $db->prepare("
                    INSERT INTO usuarios(nombre,usuario,password,rol,estado)
                    VALUES(?,?,?,?,?)
                ");
                $s->execute([$nombre,$usuario,$hash,$rol,$estado]);

                $mensaje = 'Usuario creado correctamente.';
            }
        }

        if ($accion === 'eliminar') {
            $id = (int)($_POST['id'] ?? 0);
            $actual = usuario_actual();

            if ($id === (int)($actual['id'] ?? 0)) {
                throw new Exception('No puedes eliminar tu propio usuario mientras tienes la sesión iniciada.');
            }

            $s = $db->prepare("DELETE FROM usuarios WHERE id=?");
            $s->execute([$id]);

            $mensaje = 'Usuario eliminado correctamente.';
        }
    }
} catch (Throwable $e) {
    $error = str_contains($e->getMessage(), 'Duplicate entry')
        ? 'Ese nombre de usuario ya existe.'
        : (str_contains($e->getMessage(), 'Integrity constraint')
            ? 'No se puede eliminar ese usuario porque tiene ventas registradas.'
            : $e->getMessage());
}

if (isset($_GET['editar'])) {
    $s = $db->prepare("SELECT id,nombre,usuario,rol,estado FROM usuarios WHERE id=?");
    $s->execute([(int)$_GET['editar']]);
    $editar = $s->fetch();
}

$usuarios = $db->query("
    SELECT id,nombre,usuario,rol,estado,creado_en
    FROM usuarios
    ORDER BY id DESC
")->fetchAll();

app_top('Usuarios y roles','usuarios');
?>

<?php if($mensaje): ?>
    <div class="alert alert-success"><?= htmlspecialchars($mensaje) ?></div>
<?php endif; ?>

<?php if($error): ?>
    <div class="alert alert-error"><?= htmlspecialchars($error) ?></div>
<?php endif; ?>

<section class="panel">
    <div class="panel-header">
        <h3><?= $editar ? 'Editar usuario' : 'Nuevo usuario' ?></h3>
        <span class="muted">Administrador, vendedor o cliente</span>
    </div>

    <div class="panel-body">
        <form method="post">
            <input type="hidden" name="accion" value="guardar">
            <input type="hidden" name="id" value="<?= (int)($editar['id'] ?? 0) ?>">

            <div class="form-grid">
                <div>
                    <label>Nombre completo</label>
                    <input name="nombre" required value="<?= htmlspecialchars($editar['nombre'] ?? '') ?>" placeholder="Ej. Juan Pérez">
                </div>

                <div>
                    <label>Usuario</label>
                    <input name="usuario" required value="<?= htmlspecialchars($editar['usuario'] ?? '') ?>" placeholder="Ej. jperez">
                </div>

                <div>
                    <label>Rol</label>
                    <select name="rol" required>
                        <option value="vendedor" <?= (($editar['rol'] ?? 'vendedor') === 'vendedor') ? 'selected' : '' ?>>Vendedor</option>
                        <option value="cliente" <?= (($editar['rol'] ?? '') === 'cliente') ? 'selected' : '' ?>>Cliente</option>
                        <option value="admin" <?= (($editar['rol'] ?? '') === 'admin') ? 'selected' : '' ?>>Administrador</option>
                    </select>
                </div>

                <div>
                    <label><?= $editar ? 'Nueva contraseña (opcional)' : 'Contraseña' ?></label>
                    <input type="password" name="password" <?= $editar ? '' : 'required' ?> placeholder="<?= $editar ? 'Déjala vacía para conservarla' : 'Mínimo 6 caracteres' ?>">
                </div>

                <div class="full">
                    <label>
                        <input type="checkbox" name="estado" value="1" style="width:auto;margin-right:7px" <?= ((int)($editar['estado'] ?? 1) === 1) ? 'checked' : '' ?>>
                        Usuario activo
                    </label>
                </div>

                <div class="full actions">
                    <button class="btn btn-primary" type="submit">💾 Guardar usuario</button>
                    <?php if($editar): ?>
                        <a class="btn btn-secondary" href="usuarios.php">Cancelar</a>
                    <?php endif; ?>
                </div>
            </div>
        </form>
    </div>
</section>

<section class="panel">
    <div class="panel-header">
        <h3>Usuarios registrados</h3>
        <span class="muted"><?= count($usuarios) ?> usuarios</span>
    </div>

    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Nombre</th>
                    <th>Usuario</th>
                    <th>Rol</th>
                    <th>Estado</th>
                    <th>Fecha</th>
                    <th>Acciones</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach($usuarios as $u): ?>
                <tr>
                    <td>#<?= (int)$u['id'] ?></td>
                    <td><strong><?= htmlspecialchars($u['nombre']) ?></strong></td>
                    <td><?= htmlspecialchars($u['usuario']) ?></td>
                    <td>
                        <span class="badge <?= $u['rol']==='admin' ? 'badge-blue' : 'badge-green' ?>">
                            <?= htmlspecialchars(ucfirst($u['rol'])) ?>
                        </span>
                    </td>
                    <td>
                        <span class="badge <?= (int)$u['estado']===1 ? 'badge-green' : 'badge-red' ?>">
                            <?= (int)$u['estado']===1 ? 'Activo' : 'Inactivo' ?>
                        </span>
                    </td>
                    <td><?= date('d/m/Y H:i', strtotime($u['creado_en'])) ?></td>
                    <td>
                        <div class="actions">
                            <a class="btn btn-secondary" href="?editar=<?= $u['id'] ?>">✏️ Editar</a>

                            <?php if ((int)$u['id'] !== (int)(usuario_actual()['id'] ?? 0)): ?>
                            <form method="post" onsubmit="return confirm('¿Eliminar este usuario?')">
                                <input type="hidden" name="accion" value="eliminar">
                                <input type="hidden" name="id" value="<?= $u['id'] ?>">
                                <button class="btn btn-danger" type="submit">🗑️ Eliminar</button>
                            </form>
                            <?php endif; ?>
                        </div>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</section>

<?php app_bottom(); ?>