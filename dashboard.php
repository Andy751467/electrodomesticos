<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_login();

try {
    $db = (new Database())->getConnection();

    $totalProductos = (int)$db->query("SELECT COUNT(*) FROM productos WHERE estado = 1")->fetchColumn();
    $totalClientes  = (int)$db->query("SELECT COUNT(*) FROM clientes")->fetchColumn();
    $totalVentas    = (int)$db->query("SELECT COUNT(*) FROM ventas")->fetchColumn();
    $ingresos       = (float)$db->query("SELECT COALESCE(SUM(total), 0) FROM ventas")->fetchColumn();
    $stockBajo      = (int)$db->query("SELECT COUNT(*) FROM productos WHERE stock <= 5 AND estado = 1")->fetchColumn();

    $ultimasVentas = $db->query("
        SELECT
            v.id,
            v.fecha,
            v.total,
            v.metodo_pago,
            CONCAT(COALESCE(c.nombres, 'Cliente'), ' ', COALESCE(c.apellidos, '')) AS cliente,
            COALESCE(u.nombre, 'Sin vendedor') AS vendedor
        FROM ventas v
        LEFT JOIN clientes c ON c.id = v.cliente_id
        LEFT JOIN usuarios u ON u.id = v.usuario_id
        ORDER BY v.id DESC
        LIMIT 6
    ")->fetchAll();

    $productosStockBajo = $db->query("
        SELECT
            p.id,
            p.nombre,
            p.marca,
            p.stock,
            c.nombre AS categoria
        FROM productos p
        LEFT JOIN categorias c ON c.id = p.categoria_id
        WHERE p.stock <= 5 AND p.estado = 1
        ORDER BY p.stock ASC, p.nombre ASC
        LIMIT 6
    ")->fetchAll();

} catch (Throwable $e) {
    $errorBD = $e->getMessage();
    $totalProductos = 0;
    $totalClientes = 0;
    $totalVentas = 0;
    $ingresos = 0;
    $stockBajo = 0;
    $ultimasVentas = [];
    $productosStockBajo = [];
}

function moneda(float $monto): string {
    return 'S/ ' . number_format($monto, 2, '.', ',');
}

function metodoPago(string $metodo): string {
    return ucfirst(str_replace('_', ' ', $metodo));
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard | Electrodomésticos</title>

    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        :root {
            --sidebar: #111827;
            --sidebar-hover: #1f2937;
            --principal: #2563eb;
            --principal-claro: #eff6ff;
            --fondo: #f3f4f6;
            --blanco: #ffffff;
            --texto: #111827;
            --texto-suave: #6b7280;
            --borde: #e5e7eb;
            --verde: #16a34a;
            --naranja: #ea580c;
            --rojo: #dc2626;
            --morado: #7c3aed;
        }

        body {
            font-family: "Segoe UI", Arial, sans-serif;
            background: var(--fondo);
            color: var(--texto);
        }

        .layout {
            min-height: 100vh;
            display: flex;
        }

        .sidebar {
            width: 255px;
            min-height: 100vh;
            background: var(--sidebar);
            color: white;
            padding: 24px 16px;
            position: fixed;
            left: 0;
            top: 0;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 0 10px 24px;
            border-bottom: 1px solid rgba(255,255,255,.1);
            margin-bottom: 22px;
        }

        .logo-icono {
            width: 44px;
            height: 44px;
            border-radius: 12px;
            display: grid;
            place-items: center;
            background: var(--principal);
            font-size: 22px;
        }

        .logo h2 {
            font-size: 17px;
            line-height: 1.2;
        }

        .logo span {
            display: block;
            font-size: 12px;
            color: #9ca3af;
            margin-top: 4px;
            font-weight: 400;
        }

        .menu-titulo {
            color: #9ca3af;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 1px;
            padding: 0 12px 8px;
        }

        .menu a {
            text-decoration: none;
            color: #d1d5db;
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 14px;
            border-radius: 10px;
            margin-bottom: 7px;
            transition: .2s;
            font-size: 14px;
        }

        .menu a:hover,
        .menu a.activo {
            background: var(--principal);
            color: white;
        }

        .contenido {
            margin-left: 255px;
            width: calc(100% - 255px);
            min-height: 100vh;
        }

        .topbar {
            height: 74px;
            background: white;
            border-bottom: 1px solid var(--borde);
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0 30px;
        }

        .topbar h1 {
            font-size: 22px;
        }

        .topbar p {
            color: var(--texto-suave);
            font-size: 13px;
            margin-top: 3px;
        }

        .usuario {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .avatar {
            width: 40px;
            height: 40px;
            background: var(--principal-claro);
            color: var(--principal);
            border-radius: 50%;
            display: grid;
            place-items: center;
            font-weight: 700;
        }

        main {
            padding: 28px;
        }

        .alerta-error {
            background: #fef2f2;
            color: #991b1b;
            border: 1px solid #fecaca;
            padding: 14px 16px;
            border-radius: 10px;
            margin-bottom: 20px;
        }

        .tarjetas {
            display: grid;
            grid-template-columns: repeat(5, minmax(160px, 1fr));
            gap: 18px;
            margin-bottom: 26px;
        }

        .tarjeta {
            background: white;
            border-radius: 15px;
            padding: 20px;
            border: 1px solid var(--borde);
            box-shadow: 0 3px 10px rgba(17,24,39,.04);
        }

        .tarjeta-superior {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 10px;
            margin-bottom: 15px;
        }

        .tarjeta-icono {
            width: 42px;
            height: 42px;
            border-radius: 12px;
            display: grid;
            place-items: center;
            font-size: 20px;
        }

        .azul { background: #eff6ff; color: #2563eb; }
        .verde { background: #f0fdf4; color: #16a34a; }
        .morado { background: #f5f3ff; color: #7c3aed; }
        .naranja { background: #fff7ed; color: #ea580c; }
        .rojo { background: #fef2f2; color: #dc2626; }

        .tarjeta small {
            color: var(--texto-suave);
            font-size: 13px;
        }

        .tarjeta .numero {
            font-size: 25px;
            font-weight: 700;
            margin-top: 5px;
        }

        .grid {
            display: grid;
            grid-template-columns: 1.6fr 1fr;
            gap: 22px;
        }

        .panel {
            background: white;
            border: 1px solid var(--borde);
            border-radius: 15px;
            overflow: hidden;
            box-shadow: 0 3px 10px rgba(17,24,39,.04);
        }

        .panel-header {
            padding: 18px 20px;
            border-bottom: 1px solid var(--borde);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .panel-header h3 {
            font-size: 16px;
        }

        .panel-header span {
            color: var(--texto-suave);
            font-size: 12px;
        }

        .tabla-wrap {
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th, td {
            padding: 14px 18px;
            text-align: left;
            border-bottom: 1px solid #f0f1f3;
            font-size: 13px;
            white-space: nowrap;
        }

        th {
            color: var(--texto-suave);
            font-size: 12px;
            text-transform: uppercase;
            background: #fafafa;
        }

        tbody tr:hover {
            background: #fafcff;
        }

        .badge {
            display: inline-block;
            padding: 5px 9px;
            border-radius: 999px;
            font-size: 11px;
            font-weight: 600;
            background: #eff6ff;
            color: #1d4ed8;
        }

        .badge-stock {
            background: #fef2f2;
            color: #b91c1c;
        }

        .vacio {
            padding: 35px 20px;
            color: var(--texto-suave);
            text-align: center;
            font-size: 13px;
        }

        .pie {
            margin-top: 24px;
            text-align: center;
            color: #9ca3af;
            font-size: 12px;
        }

        @media (max-width: 1200px) {
            .tarjetas {
                grid-template-columns: repeat(3, 1fr);
            }

            .grid {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 800px) {
            .sidebar {
                width: 76px;
                padding: 20px 10px;
            }

            .logo h2,
            .menu-titulo,
            .menu a span {
                display: none;
            }

            .logo {
                justify-content: center;
                padding-left: 0;
                padding-right: 0;
            }

            .menu a {
                justify-content: center;
                font-size: 18px;
            }

            .contenido {
                margin-left: 76px;
                width: calc(100% - 76px);
            }

            .tarjetas {
                grid-template-columns: repeat(2, 1fr);
            }

            .topbar {
                padding: 0 18px;
            }

            main {
                padding: 18px;
            }
        }

        @media (max-width: 520px) {
            .tarjetas {
                grid-template-columns: 1fr;
            }

            .usuario div:last-child {
                display: none;
            }
        }
    </style>
</head>
<body>

<div class="layout">

    <aside class="sidebar">
        <div class="logo">
            <div class="logo-icono">⚡</div>
            <h2>
                ElectroHogar
                <span>Sistema de Ventas</span>
            </h2>
        </div>

        <div class="menu-titulo">Menú principal</div>

        <?php $rolActual = rol_actual(); ?>
        <nav class="menu">
            <a class="activo" href="dashboard.php">📊 <span>Dashboard</span></a>
            <a href="productos.php">📺 <span>Productos</span></a>

            <?php if($rolActual === 'admin'): ?>
                <a href="categorias.php">🗂️ <span>Categorías</span></a>
            <?php endif; ?>

            <a href="clientes.php">👥 <span>Clientes</span></a>
            <a href="ventas.php">🛒 <span>Ventas</span></a>

            <?php if($rolActual === 'admin'): ?>
                <a href="usuarios.php">🔐 <span>Usuarios</span></a>
                <a href="respaldo.php">💾 <span>Respaldo BD</span></a>
            <?php endif; ?>
        </nav>
    </aside>

    <section class="contenido">

        <header class="topbar">
            <div>
                <h1>Dashboard</h1>
                <p>Resumen general del negocio de electrodomésticos</p>
            </div>

            <div class="usuario">
                <?php $u = usuario_actual(); ?>
                <div class="avatar"><?= htmlspecialchars(strtoupper(substr($u['nombre'] ?? 'U',0,1))) ?></div>
                <div>
                    <strong><?= htmlspecialchars($u['nombre'] ?? 'Usuario') ?></strong>
                    <p><?= htmlspecialchars(ucfirst($u['rol'] ?? '')) ?> · <a href="logout.php" style="color:#dc2626;text-decoration:none">Cerrar sesión</a></p>
                </div>
            </div>
        </header>

        <main>

            <?php if (isset($errorBD)): ?>
                <div class="alerta-error">
                    <strong>No se pudo conectar con la base de datos.</strong><br>
                    <?= htmlspecialchars($errorBD) ?>
                </div>
            <?php endif; ?>

            <section class="tarjetas">

                <article class="tarjeta">
                    <div class="tarjeta-superior">
                        <small>Productos</small>
                        <div class="tarjeta-icono azul">📺</div>
                    </div>
                    <div class="numero"><?= $totalProductos ?></div>
                </article>

                <article class="tarjeta">
                    <div class="tarjeta-superior">
                        <small>Clientes</small>
                        <div class="tarjeta-icono morado">👥</div>
                    </div>
                    <div class="numero"><?= $totalClientes ?></div>
                </article>

                <article class="tarjeta">
                    <div class="tarjeta-superior">
                        <small>Ventas</small>
                        <div class="tarjeta-icono verde">🛒</div>
                    </div>
                    <div class="numero"><?= $totalVentas ?></div>
                </article>

                <article class="tarjeta">
                    <div class="tarjeta-superior">
                        <small>Ingresos</small>
                        <div class="tarjeta-icono naranja">💰</div>
                    </div>
                    <div class="numero"><?= moneda($ingresos) ?></div>
                </article>

                <article class="tarjeta">
                    <div class="tarjeta-superior">
                        <small>Stock bajo</small>
                        <div class="tarjeta-icono rojo">⚠️</div>
                    </div>
                    <div class="numero"><?= $stockBajo ?></div>
                </article>

            </section>

            <section class="grid">

                <article class="panel">
                    <div class="panel-header">
                        <h3>Últimas ventas</h3>
                        <span>6 registros recientes</span>
                    </div>

                    <?php if (count($ultimasVentas) > 0): ?>
                        <div class="tabla-wrap">
                            <table>
                                <thead>
                                    <tr>
                                        <th>ID</th>
                                        <th>Cliente</th>
                                        <th>Vendedor</th>
                                        <th>Pago</th>
                                        <th>Fecha</th>
                                        <th>Total</th>
                                    </tr>
                                </thead>
                                <tbody>
                                <?php foreach ($ultimasVentas as $venta): ?>
                                    <tr>
                                        <td>#<?= (int)$venta['id'] ?></td>
                                        <td><?= htmlspecialchars(trim($venta['cliente'])) ?></td>
                                        <td><?= htmlspecialchars($venta['vendedor']) ?></td>
                                        <td>
                                            <span class="badge">
                                                <?= htmlspecialchars(metodoPago($venta['metodo_pago'])) ?>
                                            </span>
                                        </td>
                                        <td><?= date('d/m/Y H:i', strtotime($venta['fecha'])) ?></td>
                                        <td><strong><?= moneda((float)$venta['total']) ?></strong></td>
                                    </tr>
                                <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php else: ?>
                        <div class="vacio">Todavía no hay ventas registradas.</div>
                    <?php endif; ?>
                </article>

                <article class="panel">
                    <div class="panel-header">
                        <h3>Productos con stock bajo</h3>
                        <span>5 unidades o menos</span>
                    </div>

                    <?php if (count($productosStockBajo) > 0): ?>
                        <div class="tabla-wrap">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Producto</th>
                                        <th>Marca</th>
                                        <th>Stock</th>
                                    </tr>
                                </thead>
                                <tbody>
                                <?php foreach ($productosStockBajo as $producto): ?>
                                    <tr>
                                        <td>
                                            <strong><?= htmlspecialchars($producto['nombre']) ?></strong><br>
                                            <small style="color:#6b7280">
                                                <?= htmlspecialchars($producto['categoria'] ?? 'Sin categoría') ?>
                                            </small>
                                        </td>
                                        <td><?= htmlspecialchars($producto['marca']) ?></td>
                                        <td>
                                            <span class="badge badge-stock">
                                                <?= (int)$producto['stock'] ?> und.
                                            </span>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php else: ?>
                        <div class="vacio">No hay productos con stock bajo.</div>
                    <?php endif; ?>
                </article>

            </section>

            <div class="pie">
                Sistema de Venta de Electrodomésticos · PHP + MySQL
            </div>

        </main>
    </section>

</div>

</body>
</html>
