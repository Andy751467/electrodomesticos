<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_login();
require_once __DIR__ . '/includes/layout.php';

$db = (new Database())->getConnection();
$mensaje = $error = '';
$esAdmin = es_admin();

function prepararItemsVenta(PDO $db, array $productos, array $cantidades): array {
    $total = 0;
    $items = [];

    foreach ($productos as $i => $pidRaw) {
        $pid = (int)$pidRaw;
        $cant = (int)($cantidades[$i] ?? 0);

        if ($pid <= 0 || $cant <= 0) {
            continue;
        }

        $s = $db->prepare("SELECT id,nombre,precio,stock,estado FROM productos WHERE id=? FOR UPDATE");
        $s->execute([$pid]);
        $p = $s->fetch();

        if (!$p || (int)$p['estado'] !== 1) {
            throw new Exception('Uno de los productos ya no está disponible.');
        }

        if ((int)$p['stock'] < $cant) {
            throw new Exception('Stock insuficiente para '.$p['nombre'].'. Disponible: '.$p['stock']);
        }

        $precio = (float)$p['precio'];
        $subtotal = $precio * $cant;
        $total += $subtotal;

        $items[] = [
            'producto_id' => $pid,
            'cantidad' => $cant,
            'precio' => $precio,
            'subtotal' => $subtotal
        ];
    }

    if (!$items) {
        throw new Exception('Debes seleccionar al menos un producto con cantidad mayor a 0.');
    }

    return [$items, $total];
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $accion = $_POST['accion'] ?? '';

    try {
        if ($accion === 'vender') {
            $clienteId = (int)($_POST['cliente_id'] ?? 0);
            $metodo = $_POST['metodo_pago'] ?? 'efectivo';
            $productosPost = $_POST['producto_id'] ?? [];
            $cantidades = $_POST['cantidad'] ?? [];
            $observacion = trim($_POST['observacion'] ?? '');

            $permitidos = ['efectivo','yape','plin','tarjeta','transferencia'];
            if (!in_array($metodo, $permitidos, true)) {
                throw new Exception('Método de pago inválido.');
            }

            $db->beginTransaction();

            [$items, $total] = prepararItemsVenta($db, $productosPost, $cantidades);

            $usuarioId = (int)$db->query("SELECT id FROM usuarios WHERE estado=1 ORDER BY id LIMIT 1")->fetchColumn();
            if ($usuarioId <= 0) {
                throw new Exception('No existe un usuario activo para registrar la venta.');
            }

            $s = $db->prepare("
                INSERT INTO ventas(cliente_id,usuario_id,fecha,total,metodo_pago,observacion)
                VALUES(?,?,NOW(),?,?,?)
            ");
            $s->execute([
                $clienteId > 0 ? $clienteId : null,
                $usuarioId,
                $total,
                $metodo,
                $observacion ?: null
            ]);

            $ventaId = (int)$db->lastInsertId();

            $sd = $db->prepare("
                INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal)
                VALUES(?,?,?,?,?)
            ");
            $ss = $db->prepare("UPDATE productos SET stock=stock-? WHERE id=?");

            foreach ($items as $it) {
                $sd->execute([$ventaId,$it['producto_id'],$it['cantidad'],$it['precio'],$it['subtotal']]);
                $ss->execute([$it['cantidad'],$it['producto_id']]);
            }

            $db->commit();
            $mensaje = 'Venta #'.$ventaId.' registrada correctamente. Total: S/ '.number_format($total,2);
        }

        if ($accion === 'actualizar') {
            if (!$esAdmin) throw new Exception('Solo el administrador puede editar ventas.');
            $ventaId = (int)($_POST['venta_id'] ?? 0);
            $clienteId = (int)($_POST['cliente_id'] ?? 0);
            $metodo = $_POST['metodo_pago'] ?? 'efectivo';
            $productosPost = $_POST['producto_id'] ?? [];
            $cantidades = $_POST['cantidad'] ?? [];
            $observacion = trim($_POST['observacion'] ?? '');

            $permitidos = ['efectivo','yape','plin','tarjeta','transferencia'];
            if ($ventaId <= 0) throw new Exception('Venta inválida.');
            if (!in_array($metodo, $permitidos, true)) throw new Exception('Método de pago inválido.');

            $db->beginTransaction();

            $sv = $db->prepare("SELECT id FROM ventas WHERE id=? FOR UPDATE");
            $sv->execute([$ventaId]);
            if (!$sv->fetch()) {
                throw new Exception('La venta ya no existe.');
            }

            $sdOld = $db->prepare("SELECT producto_id,cantidad FROM detalle_venta WHERE venta_id=?");
            $sdOld->execute([$ventaId]);
            $itemsViejos = $sdOld->fetchAll();

            $restaurar = $db->prepare("UPDATE productos SET stock=stock+? WHERE id=?");
            foreach ($itemsViejos as $old) {
                $restaurar->execute([(int)$old['cantidad'], (int)$old['producto_id']]);
            }

            [$items, $total] = prepararItemsVenta($db, $productosPost, $cantidades);

            $su = $db->prepare("
                UPDATE ventas
                SET cliente_id=?, total=?, metodo_pago=?, observacion=?
                WHERE id=?
            ");
            $su->execute([
                $clienteId > 0 ? $clienteId : null,
                $total,
                $metodo,
                $observacion ?: null,
                $ventaId
            ]);

            $db->prepare("DELETE FROM detalle_venta WHERE venta_id=?")->execute([$ventaId]);

            $insertar = $db->prepare("
                INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal)
                VALUES(?,?,?,?,?)
            ");
            $descontar = $db->prepare("UPDATE productos SET stock=stock-? WHERE id=?");

            foreach ($items as $it) {
                $insertar->execute([$ventaId,$it['producto_id'],$it['cantidad'],$it['precio'],$it['subtotal']]);
                $descontar->execute([$it['cantidad'],$it['producto_id']]);
            }

            $db->commit();
            $mensaje = 'Venta #'.$ventaId.' actualizada correctamente. Total: S/ '.number_format($total,2);
        }

        if ($accion === 'eliminar') {
            if (!$esAdmin) throw new Exception('Solo el administrador puede eliminar ventas.');
            $ventaId = (int)($_POST['venta_id'] ?? 0);
            if ($ventaId <= 0) throw new Exception('Venta inválida.');

            $db->beginTransaction();

            $sv = $db->prepare("SELECT id FROM ventas WHERE id=? FOR UPDATE");
            $sv->execute([$ventaId]);
            if (!$sv->fetch()) {
                throw new Exception('La venta ya no existe.');
            }

            $sd = $db->prepare("SELECT producto_id,cantidad FROM detalle_venta WHERE venta_id=?");
            $sd->execute([$ventaId]);
            $items = $sd->fetchAll();

            $restaurar = $db->prepare("UPDATE productos SET stock=stock+? WHERE id=?");
            foreach ($items as $it) {
                $restaurar->execute([(int)$it['cantidad'], (int)$it['producto_id']]);
            }

            $db->prepare("DELETE FROM ventas WHERE id=?")->execute([$ventaId]);

            $db->commit();
            $mensaje = 'Venta #'.$ventaId.' eliminada y el stock fue devuelto correctamente.';
        }

    } catch (Throwable $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        $error = $e->getMessage();
    }
}

$clientes = $db->query("
    SELECT id, CONCAT(nombres,' ',COALESCE(apellidos,'')) nombre
    FROM clientes
    ORDER BY nombres
")->fetchAll();

$productos = $db->query("
    SELECT id,nombre,marca,precio,stock
    FROM productos
    WHERE estado=1
    ORDER BY nombre
")->fetchAll();

$editarVenta = null;
$editarItems = [];

if (isset($_GET['editar'])) {
    if (!$esAdmin) {
        http_response_code(403);
        die('Acceso denegado: solo el administrador puede editar ventas.');
    }
    $id = (int)$_GET['editar'];

    $s = $db->prepare("SELECT * FROM ventas WHERE id=?");
    $s->execute([$id]);
    $editarVenta = $s->fetch();

    if ($editarVenta) {
        $s2 = $db->prepare("
            SELECT producto_id,cantidad,precio_unitario,subtotal
            FROM detalle_venta
            WHERE venta_id=?
            ORDER BY id
        ");
        $s2->execute([$id]);
        $editarItems = $s2->fetchAll();
    }
}

$ventas = $db->query("
    SELECT
        v.*,
        CONCAT(COALESCE(c.nombres,'Cliente'),' ',COALESCE(c.apellidos,'')) cliente,
        u.nombre vendedor
    FROM ventas v
    LEFT JOIN clientes c ON c.id=v.cliente_id
    LEFT JOIN usuarios u ON u.id=v.usuario_id
    ORDER BY v.id DESC
")->fetchAll();

$detalle = null;
if (isset($_GET['ver'])) {
    $id = (int)$_GET['ver'];

    $s = $db->prepare("
        SELECT
            v.*,
            CONCAT(COALESCE(c.nombres,'Cliente'),' ',COALESCE(c.apellidos,'')) cliente,
            u.nombre vendedor
        FROM ventas v
        LEFT JOIN clientes c ON c.id=v.cliente_id
        LEFT JOIN usuarios u ON u.id=v.usuario_id
        WHERE v.id=?
    ");
    $s->execute([$id]);
    $detalle = $s->fetch();

    if ($detalle) {
        $s2 = $db->prepare("
            SELECT d.*,p.nombre producto,p.marca
            FROM detalle_venta d
            JOIN productos p ON p.id=d.producto_id
            WHERE d.venta_id=?
        ");
        $s2->execute([$id]);
        $detalle['items'] = $s2->fetchAll();
    }
}

app_top('Ventas','ventas');
?>

<?php if($mensaje): ?>
    <div class="alert alert-success"><?= htmlspecialchars($mensaje) ?></div>
<?php endif; ?>

<?php if($error): ?>
    <div class="alert alert-error"><?= htmlspecialchars($error) ?></div>
<?php endif; ?>

<section class="panel">
    <div class="panel-header">
        <h3><?= $editarVenta ? 'Editar venta #'.(int)$editarVenta['id'] : 'Nueva venta' ?></h3>
        <span class="muted">
            <?= $editarVenta ? 'Al guardar, el stock se recalcula automáticamente' : 'El stock se descuenta automáticamente' ?>
        </span>
    </div>

    <div class="panel-body">
        <form method="post" id="ventaForm">
            <input type="hidden" name="accion" value="<?= $editarVenta ? 'actualizar' : 'vender' ?>">
            <input type="hidden" name="venta_id" value="<?= (int)($editarVenta['id'] ?? 0) ?>">

            <div class="form-grid">
                <div>
                    <label>Cliente</label>
                    <select name="cliente_id">
                        <option value="0">Cliente general</option>
                        <?php foreach($clientes as $c): ?>
                            <option value="<?= $c['id'] ?>"
                                <?= ((int)($editarVenta['cliente_id'] ?? 0) === (int)$c['id']) ? 'selected' : '' ?>>
                                <?= htmlspecialchars(trim($c['nombre'])) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div>
                    <label>Método de pago</label>
                    <?php $metodoActual = $editarVenta['metodo_pago'] ?? 'efectivo'; ?>
                    <select name="metodo_pago">
                        <option value="efectivo" <?= $metodoActual==='efectivo'?'selected':'' ?>>Efectivo</option>
                        <option value="yape" <?= $metodoActual==='yape'?'selected':'' ?>>Yape</option>
                        <option value="plin" <?= $metodoActual==='plin'?'selected':'' ?>>Plin</option>
                        <option value="tarjeta" <?= $metodoActual==='tarjeta'?'selected':'' ?>>Tarjeta</option>
                        <option value="transferencia" <?= $metodoActual==='transferencia'?'selected':'' ?>>Transferencia</option>
                    </select>
                </div>

                <div class="full">
                    <label>Productos</label>
                    <div id="filas"></div>
                    <button type="button" class="btn btn-secondary" onclick="agregarFila()">➕ Agregar producto</button>
                </div>

                <div class="full">
                    <label>Observación</label>
                    <textarea name="observacion" placeholder="Opcional"><?= htmlspecialchars($editarVenta['observacion'] ?? '') ?></textarea>
                </div>

                <div class="full total-box">
                    Total estimado:
                    <span id="totalVista" style="margin-left:8px">S/ 0.00</span>
                </div>

                <div class="full actions">
                    <button class="btn btn-primary" type="submit">
                        <?= $editarVenta ? '💾 Guardar cambios' : '✅ Registrar venta' ?>
                    </button>

                    <?php if($editarVenta): ?>
                        <a class="btn btn-secondary" href="ventas.php">Cancelar edición</a>
                    <?php endif; ?>
                </div>
            </div>
        </form>
    </div>
</section>

<?php if($detalle): ?>
<section class="panel">
    <div class="panel-header">
        <h3>Detalle de venta #<?= $detalle['id'] ?></h3>
        <a class="btn btn-secondary" href="ventas.php">Cerrar</a>
    </div>

    <div class="panel-body">
        <p>
            <strong>Cliente:</strong> <?= htmlspecialchars(trim($detalle['cliente'])) ?>
            &nbsp; <strong>Pago:</strong> <?= htmlspecialchars(ucfirst($detalle['metodo_pago'])) ?>
            &nbsp; <strong>Total:</strong> S/ <?= number_format((float)$detalle['total'],2) ?>
        </p>

        <?php if(!empty($detalle['observacion'])): ?>
            <p style="margin-top:10px"><strong>Observación:</strong> <?= htmlspecialchars($detalle['observacion']) ?></p>
        <?php endif; ?>
    </div>

    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>Producto</th>
                    <th>Cantidad</th>
                    <th>Precio</th>
                    <th>Subtotal</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach($detalle['items'] as $i): ?>
                <tr>
                    <td><?= htmlspecialchars($i['producto'].' - '.$i['marca']) ?></td>
                    <td><?= (int)$i['cantidad'] ?></td>
                    <td>S/ <?= number_format((float)$i['precio_unitario'],2) ?></td>
                    <td class="money">S/ <?= number_format((float)$i['subtotal'],2) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</section>
<?php endif; ?>

<section class="panel">
    <div class="panel-header">
        <h3>Historial de ventas</h3>
        <span class="muted"><?= count($ventas) ?> ventas</span>
    </div>

    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Fecha</th>
                    <th>Cliente</th>
                    <th>Vendedor</th>
                    <th>Pago</th>
                    <th>Total</th>
                    <th>Acciones</th>
                </tr>
            </thead>

            <tbody>
            <?php foreach($ventas as $v): ?>
                <tr>
                    <td>#<?= $v['id'] ?></td>
                    <td><?= date('d/m/Y H:i', strtotime($v['fecha'])) ?></td>
                    <td><?= htmlspecialchars(trim($v['cliente'])) ?></td>
                    <td><?= htmlspecialchars($v['vendedor'] ?? '') ?></td>
                    <td><span class="badge badge-blue"><?= htmlspecialchars(ucfirst($v['metodo_pago'])) ?></span></td>
                    <td class="money">S/ <?= number_format((float)$v['total'],2) ?></td>
                    <td>
                        <div class="actions">
                            <a class="btn btn-secondary" href="?ver=<?= $v['id'] ?>">👁️ Ver</a>
                            <?php if($esAdmin): ?>
                            <a class="btn btn-secondary" href="?editar=<?= $v['id'] ?>">✏️ Editar</a>

                            <form method="post" onsubmit="return confirm('¿Eliminar la venta #<?= $v['id'] ?>? El stock de sus productos será devuelto.')">
                                <input type="hidden" name="accion" value="eliminar">
                                <input type="hidden" name="venta_id" value="<?= $v['id'] ?>">
                                <button class="btn btn-danger" type="submit">🗑️ Eliminar</button>
                            </form>
                            <?php endif; ?>
                        </div>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if(!$ventas): ?>
                <tr><td colspan="7" class="empty">No hay ventas registradas.</td></tr>
            <?php endif; ?>
            </tbody>
        </table>
    </div>
</section>

<script>
const productos = <?= json_encode($productos, JSON_UNESCAPED_UNICODE) ?>;
const itemsIniciales = <?= json_encode($editarItems, JSON_UNESCAPED_UNICODE) ?>;

function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, m => ({
        '&':'&amp;',
        '<':'&lt;',
        '>':'&gt;',
        '"':'&quot;',
        "'":'&#039;'
    }[m]));
}

function opciones(productoSeleccionado = 0) {
    return '<option value="">Seleccione producto</option>' +
        productos.map(p => {
            const selected = Number(productoSeleccionado) === Number(p.id) ? ' selected' : '';
            return '<option value="' + p.id + '" data-precio="' + p.precio + '"' + selected + '>' +
                escapeHtml(p.nombre) + ' - ' + escapeHtml(p.marca) +
                ' | Stock actual: ' + p.stock +
                ' | S/ ' + Number(p.precio).toFixed(2) +
            '</option>';
        }).join('');
}

function agregarFila(productoId = 0, cantidad = 1) {
    const div = document.createElement('div');
    div.className = 'sale-row';

    div.innerHTML =
        '<div><label>Producto</label><select name="producto_id[]" onchange="recalcular()">' +
        opciones(productoId) +
        '</select></div>' +
        '<div><label>Cantidad</label><input type="number" name="cantidad[]" min="1" value="' + Number(cantidad || 1) + '" oninput="recalcular()"></div>' +
        '<div class="subtotal">S/ 0.00</div>' +
        '<button type="button" class="btn btn-danger" onclick="this.parentElement.remove();recalcular()">✕</button>';

    document.getElementById('filas').appendChild(div);
    recalcular();
}

function recalcular() {
    let total = 0;

    document.querySelectorAll('.sale-row').forEach(f => {
        const sel = f.querySelector('select');
        const cant = Number(f.querySelector('input').value || 0);
        const opt = sel.options[sel.selectedIndex];
        const precio = Number(opt?.dataset?.precio || 0);
        const sub = precio * cant;

        total += sub;
        f.querySelector('.subtotal').textContent = 'S/ ' + sub.toFixed(2);
    });

    document.getElementById('totalVista').textContent = 'S/ ' + total.toFixed(2);
}

if (itemsIniciales.length > 0) {
    itemsIniciales.forEach(i => agregarFila(i.producto_id, i.cantidad));
} else {
    agregarFila();
}
</script>

<?php app_bottom(); ?>