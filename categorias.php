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
            $descripcion = trim($_POST['descripcion'] ?? '');
            if ($nombre === '') throw new Exception('El nombre de la categoría es obligatorio.');
            if ($id > 0) {
                $s = $db->prepare("UPDATE categorias SET nombre=?, descripcion=? WHERE id=?");
                $s->execute([$nombre,$descripcion ?: null,$id]);
                $mensaje = 'Categoría actualizada correctamente.';
            } else {
                $s = $db->prepare("INSERT INTO categorias(nombre,descripcion) VALUES(?,?)");
                $s->execute([$nombre,$descripcion ?: null]);
                $mensaje = 'Categoría registrada correctamente.';
            }
        }
        if ($accion === 'eliminar') {
            $id = (int)($_POST['id'] ?? 0);
            $s = $db->prepare("DELETE FROM categorias WHERE id=?");
            $s->execute([$id]);
            $mensaje = 'Categoría eliminada correctamente.';
        }
    }
} catch (Throwable $e) {
    $error = str_contains($e->getMessage(), 'foreign key') || str_contains($e->getMessage(), 'Integrity constraint')
        ? 'No se puede eliminar la categoría porque tiene productos asociados.'
        : $e->getMessage();
}
if (isset($_GET['editar'])) {
    $s=$db->prepare("SELECT * FROM categorias WHERE id=?");$s->execute([(int)$_GET['editar']]);$editar=$s->fetch();
}
$categorias=$db->query("SELECT c.*, (SELECT COUNT(*) FROM productos p WHERE p.categoria_id=c.id) productos FROM categorias c ORDER BY c.id DESC")->fetchAll();
app_top('Categorías','categorias');
?>
<?php if($mensaje): ?><div class="alert alert-success"><?=htmlspecialchars($mensaje)?></div><?php endif; ?>
<?php if($error): ?><div class="alert alert-error"><?=htmlspecialchars($error)?></div><?php endif; ?>

<section class="panel">
    <div class="panel-header"><h3><?= $editar ? 'Editar categoría' : 'Nueva categoría' ?></h3></div>
    <div class="panel-body">
        <form method="post">
            <input type="hidden" name="accion" value="guardar">
            <input type="hidden" name="id" value="<?= (int)($editar['id'] ?? 0) ?>">
            <div class="form-grid">
                <div><label>Nombre</label><input name="nombre" required value="<?=htmlspecialchars($editar['nombre'] ?? '')?>" placeholder="Ej. Televisores"></div>
                <div><label>Descripción</label><input name="descripcion" value="<?=htmlspecialchars($editar['descripcion'] ?? '')?>" placeholder="Descripción de la categoría"></div>
                <div class="full actions">
                    <button class="btn btn-primary" type="submit">💾 Guardar</button>
                    <?php if($editar): ?><a class="btn btn-secondary" href="categorias.php">Cancelar</a><?php endif; ?>
                </div>
            </div>
        </form>
    </div>
</section>

<section class="panel">
    <div class="panel-header"><h3>Lista de categorías</h3><span class="muted"><?=count($categorias)?> registros</span></div>
    <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Nombre</th><th>Descripción</th><th>Productos</th><th>Acciones</th></tr></thead>
        <tbody>
        <?php foreach($categorias as $c): ?>
            <tr>
                <td>#<?= (int)$c['id'] ?></td>
                <td><strong><?=htmlspecialchars($c['nombre'])?></strong></td>
                <td><?=htmlspecialchars($c['descripcion'] ?? '')?></td>
                <td><span class="badge badge-blue"><?= (int)$c['productos'] ?></span></td>
                <td><div class="actions">
                    <a class="btn btn-secondary" href="?editar=<?=$c['id']?>">✏️ Editar</a>
                    <form method="post" onsubmit="return confirm('¿Eliminar esta categoría?')">
                        <input type="hidden" name="accion" value="eliminar"><input type="hidden" name="id" value="<?=$c['id']?>">
                        <button class="btn btn-danger">🗑️ Eliminar</button>
                    </form>
                </div></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table></div>
</section>
<?php app_bottom(); ?>