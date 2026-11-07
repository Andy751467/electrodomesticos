<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_login();
require_once __DIR__ . '/includes/layout.php';

$db = (new Database())->getConnection();
$esAdmin = es_admin();
$mensaje = $error = '';
$editar = null;

/* Compatibilidad con bases ya creadas */
try {
    $columnas = $db->query("SHOW COLUMNS FROM productos")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('codigo_sku', $columnas, true)) {
        $db->exec("ALTER TABLE productos ADD codigo_sku VARCHAR(50) NULL AFTER categoria_id");
    }
    if (!in_array('stock_minimo', $columnas, true)) {
        $db->exec("ALTER TABLE productos ADD stock_minimo INT NOT NULL DEFAULT 5 AFTER stock");
    }
    if (!in_array('imagen', $columnas, true)) {
        $db->exec("ALTER TABLE productos ADD imagen VARCHAR(255) NULL AFTER descripcion");
    }

    $db->exec("UPDATE productos
               SET codigo_sku = CONCAT('PROD-', LPAD(id, 4, '0'))
               WHERE codigo_sku IS NULL OR TRIM(codigo_sku) = ''");

    $indices = $db->query("SHOW INDEX FROM productos WHERE Key_name='idx_producto_sku'")->fetchAll();
    if (!$indices) {
        $db->exec("ALTER TABLE productos ADD UNIQUE INDEX idx_producto_sku (codigo_sku)");
    }
} catch (Throwable $e) {
    $error = 'No se pudo actualizar la estructura de productos: ' . $e->getMessage();
}

function guardarImagenProducto(array $archivo, ?string $imagenActual = null): ?string {
    if (($archivo['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        return $imagenActual;
    }

    if (($archivo['error'] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
        throw new Exception('No se pudo subir la imagen.');
    }

    if (($archivo['size'] ?? 0) > 2 * 1024 * 1024) {
        throw new Exception('La imagen no puede pesar más de 2 MB.');
    }

    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($archivo['tmp_name']);

    $permitidos = [
        'image/jpeg' => 'jpg',
        'image/png'  => 'png',
        'image/webp' => 'webp'
    ];

    if (!isset($permitidos[$mime])) {
        throw new Exception('Solo se permiten imágenes JPG, PNG o WEBP.');
    }

    $carpeta = __DIR__ . '/uploads/productos';
    if (!is_dir($carpeta) && !mkdir($carpeta, 0775, true) && !is_dir($carpeta)) {
        throw new Exception('No se pudo crear la carpeta de imágenes.');
    }

    $nombre = 'producto_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.' . $permitidos[$mime];
    $destino = $carpeta . '/' . $nombre;

    if (!move_uploaded_file($archivo['tmp_name'], $destino)) {
        throw new Exception('No se pudo guardar la imagen del producto.');
    }

    if ($imagenActual && str_starts_with($imagenActual, 'uploads/productos/')) {
        $anterior = __DIR__ . '/' . $imagenActual;
        if (is_file($anterior)) {
            @unlink($anterior);
        }
    }

    return 'uploads/productos/' . $nombre;
}

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!$esAdmin) {
            throw new Exception('Solo el administrador puede registrar, editar o desactivar productos.');
        }

        $accion = $_POST['accion'] ?? '';

        if ($accion === 'guardar') {
            $id = (int)($_POST['id'] ?? 0);
            $categoria = (int)($_POST['categoria_id'] ?? 0);
            $sku = strtoupper(trim($_POST['codigo_sku'] ?? ''));
            $nombre = trim($_POST['nombre'] ?? '');
            $marca = trim($_POST['marca'] ?? '');
            $modelo = trim($_POST['modelo'] ?? '');
            $precio = (float)($_POST['precio'] ?? 0);
            $stock = (int)($_POST['stock'] ?? 0);
            $stockMinimo = (int)($_POST['stock_minimo'] ?? 0);
            $descripcion = trim($_POST['descripcion'] ?? '');

            if ($categoria <= 0 || $sku === '' || $nombre === '' || $marca === '') {
                throw new Exception('Categoría, SKU, nombre y marca son obligatorios.');
            }

            if (!preg_match('/^[A-Z0-9\-_]{3,50}$/', $sku)) {
                throw new Exception('El SKU solo puede contener letras, números, guion y guion bajo.');
            }

            if ($precio < 0 || $stock < 0 || $stockMinimo < 0) {
                throw new Exception('Precio, stock y stock mínimo no pueden ser negativos.');
            }

            $imagenActual = null;
            if ($id > 0) {
                $si = $db->prepare("SELECT imagen FROM productos WHERE id=?");
                $si->execute([$id]);
                $imagenActual = $si->fetchColumn() ?: null;
            }

            if (!empty($_POST['eliminar_imagen']) && $imagenActual) {
                if (str_starts_with($imagenActual, 'uploads/productos/')) {
                    $ruta = __DIR__ . '/' . $imagenActual;
                    if (is_file($ruta)) @unlink($ruta);
                }
                $imagenActual = null;
            }

            $imagen = guardarImagenProducto($_FILES['imagen'] ?? [], $imagenActual);

            if ($id > 0) {
                $s = $db->prepare("
                    UPDATE productos
                    SET categoria_id=?, codigo_sku=?, nombre=?, marca=?, modelo=?, precio=?,
                        stock=?, stock_minimo=?, descripcion=?, imagen=?, estado=1
                    WHERE id=?
                ");
                $s->execute([
                    $categoria,$sku,$nombre,$marca,$modelo ?: null,$precio,
                    $stock,$stockMinimo,$descripcion ?: null,$imagen,$id
                ]);
                $mensaje = 'Producto actualizado correctamente.';
            } else {
                $s = $db->prepare("
                    INSERT INTO productos
                    (categoria_id,codigo_sku,nombre,marca,modelo,precio,stock,stock_minimo,descripcion,imagen,estado)
                    VALUES(?,?,?,?,?,?,?,?,?,?,1)
                ");
                $s->execute([
                    $categoria,$sku,$nombre,$marca,$modelo ?: null,$precio,
                    $stock,$stockMinimo,$descripcion ?: null,$imagen
                ]);
                $mensaje = 'Producto registrado correctamente.';
            }
        }

        if ($accion === 'eliminar') {
            $id = (int)($_POST['id'] ?? 0);
            $s = $db->prepare("UPDATE productos SET estado=0 WHERE id=?");
            $s->execute([$id]);
            $mensaje = 'Producto desactivado correctamente.';
        }
    }
} catch (Throwable $e) {
    if (str_contains($e->getMessage(), 'Duplicate entry')) {
        $error = 'El código SKU ya está registrado. Usa un SKU diferente.';
    } else {
        $error = $e->getMessage();
    }
}

if (isset($_GET['editar'])) {
    if (!$esAdmin) {
        http_response_code(403);
        die('Acceso denegado: solo el administrador puede editar productos.');
    }

    $s = $db->prepare("SELECT * FROM productos WHERE id=?");
    $s->execute([(int)$_GET['editar']]);
    $editar = $s->fetch();
}

$categorias = $db->query("SELECT id,nombre FROM categorias ORDER BY nombre")->fetchAll();

$q = trim($_GET['q'] ?? '');
if ($q !== '') {
    $s = $db->prepare("
        SELECT p.*, c.nombre categoria
        FROM productos p
        JOIN categorias c ON c.id=p.categoria_id
        WHERE p.estado=1
          AND (p.codigo_sku LIKE ? OR p.nombre LIKE ? OR p.marca LIKE ? OR p.modelo LIKE ?)
        ORDER BY p.id DESC
    ");
    $like = "%$q%";
    $s->execute([$like,$like,$like,$like]);
    $productos = $s->fetchAll();
} else {
    $productos = $db->query("
        SELECT p.*, c.nombre categoria
        FROM productos p
        JOIN categorias c ON c.id=p.categoria_id
        WHERE p.estado=1
        ORDER BY p.id DESC
    ")->fetchAll();
}

app_top('Productos','productos');
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
            <h3><?= $editar ? 'Editar producto' : 'Nuevo producto' ?></h3>
            <span class="muted">SKU, imagen y control de stock mínimo</span>
        </div>
    </div>

    <div class="panel-body">
        <form method="post" enctype="multipart/form-data">
            <input type="hidden" name="accion" value="guardar">
            <input type="hidden" name="id" value="<?= (int)($editar['id'] ?? 0) ?>">

            <div class="form-grid">
                <div>
                    <label>Código SKU</label>
                    <input
                        name="codigo_sku"
                        maxlength="50"
                        required
                        value="<?= htmlspecialchars($editar['codigo_sku'] ?? '') ?>"
                        placeholder="Ej. TV-SAM-001"
                    >
                    <small class="form-help">Debe ser único para cada producto.</small>
                </div>

                <div>
                    <label>Categoría</label>
                    <select name="categoria_id" required>
                        <option value="">Seleccione</option>
                        <?php foreach($categorias as $c): ?>
                            <option value="<?= $c['id'] ?>" <?= ((int)($editar['categoria_id'] ?? 0) === (int)$c['id']) ? 'selected' : '' ?>>
                                <?= htmlspecialchars($c['nombre']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div>
                    <label>Nombre</label>
                    <input name="nombre" required value="<?= htmlspecialchars($editar['nombre'] ?? '') ?>" placeholder="Ej. Smart TV 55 pulgadas">
                </div>

                <div>
                    <label>Marca</label>
                    <input name="marca" required value="<?= htmlspecialchars($editar['marca'] ?? '') ?>" placeholder="Ej. Samsung">
                </div>

                <div>
                    <label>Modelo</label>
                    <input name="modelo" value="<?= htmlspecialchars($editar['modelo'] ?? '') ?>" placeholder="Ej. UHD55">
                </div>

                <div>
                    <label>Precio de venta (S/)</label>
                    <input type="number" step="0.01" min="0" name="precio" required value="<?= htmlspecialchars((string)($editar['precio'] ?? '')) ?>">
                </div>

                <div>
                    <label>Stock actual</label>
                    <input type="number" min="0" name="stock" required value="<?= htmlspecialchars((string)($editar['stock'] ?? '')) ?>">
                </div>

                <div>
                    <label>Stock mínimo</label>
                    <input type="number" min="0" name="stock_minimo" required value="<?= htmlspecialchars((string)($editar['stock_minimo'] ?? 5)) ?>">
                    <small class="form-help">Al llegar a este nivel se marcará como stock bajo.</small>
                </div>

                <div class="full">
                    <label>Imagen del producto</label>
                    <div class="product-image-upload">
                        <?php if(!empty($editar['imagen'])): ?>
                            <img class="product-preview" src="<?= htmlspecialchars($editar['imagen']) ?>" alt="Imagen actual">
                        <?php else: ?>
                            <div class="product-preview product-preview-empty">📦</div>
                        <?php endif; ?>

                        <div class="product-upload-controls">
                            <input type="file" name="imagen" accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp">
                            <small class="form-help">JPG, PNG o WEBP. Máximo 2 MB.</small>

                            <?php if(!empty($editar['imagen'])): ?>
                                <label class="check-inline">
                                    <input type="checkbox" name="eliminar_imagen" value="1">
                                    Quitar imagen actual
                                </label>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>

                <div class="full">
                    <label>Descripción</label>
                    <textarea name="descripcion"><?= htmlspecialchars($editar['descripcion'] ?? '') ?></textarea>
                </div>

                <div class="full actions">
                    <button class="btn btn-primary" type="submit">💾 Guardar producto</button>
                    <?php if($editar): ?>
                        <a class="btn btn-secondary" href="productos.php">Cancelar</a>
                    <?php endif; ?>
                </div>
            </div>
        </form>
    </div>
</section>
<?php else: ?>
<div class="alert alert-info">
    Estás ingresando como vendedor. Puedes consultar productos y stock, pero solo el administrador puede modificarlos.
</div>
<?php endif; ?>

<div class="toolbar">
    <form class="search" method="get">
        <input name="q" value="<?= htmlspecialchars($q) ?>" placeholder="Buscar por SKU, nombre, marca o modelo">
        <button class="btn btn-primary">🔎 Buscar</button>
        <?php if($q !== ''): ?>
            <a class="btn btn-secondary" href="productos.php">Limpiar</a>
        <?php endif; ?>
    </form>
</div>

<section class="panel">
    <div class="panel-header">
        <h3>Inventario de productos</h3>
        <span class="muted"><?= count($productos) ?> productos</span>
    </div>

    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>Imagen</th>
                    <th>SKU</th>
                    <th>Producto</th>
                    <th>Categoría</th>
                    <th>Marca/Modelo</th>
                    <th>Precio</th>
                    <th>Stock</th>
                    <th>Acciones</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach($productos as $p): ?>
                <?php $stockBajo = (int)$p['stock'] <= (int)$p['stock_minimo']; ?>
                <tr>
                    <td>
                        <?php if(!empty($p['imagen'])): ?>
                            <img class="product-thumb" src="<?= htmlspecialchars($p['imagen']) ?>" alt="<?= htmlspecialchars($p['nombre']) ?>">
                        <?php else: ?>
                            <div class="product-thumb product-thumb-empty">📦</div>
                        <?php endif; ?>
                    </td>

                    <td>
                        <span class="sku-badge"><?= htmlspecialchars($p['codigo_sku'] ?? '-') ?></span>
                    </td>

                    <td>
                        <strong><?= htmlspecialchars($p['nombre']) ?></strong><br>
                        <small class="muted"><?= htmlspecialchars($p['descripcion'] ?? '') ?></small>
                    </td>

                    <td><?= htmlspecialchars($p['categoria']) ?></td>

                    <td>
                        <?= htmlspecialchars($p['marca']) ?>
                        <?= htmlspecialchars($p['modelo'] ?? '') ?>
                    </td>

                    <td class="money">S/ <?= number_format((float)$p['precio'],2) ?></td>

                    <td>
                        <span class="badge <?= $stockBajo ? 'badge-red' : 'badge-green' ?>">
                            <?= (int)$p['stock'] ?> und.
                        </span>
                        <br>
                        <small class="muted">Mín: <?= (int)$p['stock_minimo'] ?></small>
                    </td>

                    <td>
                        <?php if($esAdmin): ?>
                            <div class="actions">
                                <a class="btn btn-secondary" href="?editar=<?= $p['id'] ?>">✏️ Editar</a>
                                <form method="post" onsubmit="return confirm('¿Desactivar este producto?')">
                                    <input type="hidden" name="accion" value="eliminar">
                                    <input type="hidden" name="id" value="<?= $p['id'] ?>">
                                    <button class="btn btn-danger">🗑️ Desactivar</button>
                                </form>
                            </div>
                        <?php else: ?>
                            <span class="badge badge-blue">Solo lectura</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if(!$productos): ?>
                <tr><td colspan="8" class="empty">No se encontraron productos.</td></tr>
            <?php endif; ?>
            </tbody>
        </table>
    </div>
</section>

<?php app_bottom(); ?>