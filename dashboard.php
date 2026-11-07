<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_login();

try {
    $db = (new Database())->getConnection();

    // Mantener compatibilidad con bases de datos creadas antes del stock mínimo.
    $colStockMinimo = $db->query("SHOW COLUMNS FROM productos LIKE 'stock_minimo'")->fetch();
    if (!$colStockMinimo) {
        $db->exec("ALTER TABLE productos ADD stock_minimo INT NOT NULL DEFAULT 5 AFTER stock");
    }

    $totalProductos = (int)$db->query("SELECT COUNT(*) FROM productos WHERE estado = 1")->fetchColumn();
    $totalClientes  = (int)$db->query("SELECT COUNT(*) FROM clientes")->fetchColumn();
    $totalVentas    = (int)$db->query("SELECT COUNT(*) FROM ventas")->fetchColumn();
    $ingresos       = (float)$db->query("SELECT COALESCE(SUM(total), 0) FROM ventas")->fetchColumn();
    $stockBajo      = (int)$db->query("SELECT COUNT(*) FROM productos WHERE stock <= stock_minimo AND estado = 1")->fetchColumn();

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

    // Datos reales para los graficos (consultas de solo lectura).
    $resumenMeses = $db->query("SELECT DATE_FORMAT(fecha, '%Y-%m') AS mes,
                COUNT(*) AS cantidad, COALESCE(SUM(total), 0) AS ingresos
            FROM ventas WHERE fecha >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 5 MONTH), '%Y-%m-01')
            GROUP BY DATE_FORMAT(fecha, '%Y-%m') ORDER BY mes")->fetchAll();
    $resumenPagos = $db->query("SELECT metodo_pago AS metodo, COUNT(*) AS cantidad
            FROM ventas GROUP BY metodo_pago ORDER BY cantidad DESC")->fetchAll();
    $productosMasVendidos = $db->query("SELECT p.nombre, COALESCE(SUM(dv.cantidad),0) AS unidades
            FROM detalle_venta dv INNER JOIN productos p ON p.id = dv.producto_id
            GROUP BY p.id, p.nombre ORDER BY unidades DESC, p.nombre ASC LIMIT 6")->fetchAll();

    $productosStockBajo = $db->query("
        SELECT
            p.id,
            p.nombre,
            p.marca,
            p.stock,
            c.nombre AS categoria
        FROM productos p
        LEFT JOIN categorias c ON c.id = p.categoria_id
        WHERE p.stock <= p.stock_minimo AND p.estado = 1
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
    $resumenMeses = [];
    $resumenPagos = [];
    $productosMasVendidos = [];
}

// Generar seis meses consecutivos, incluyendo meses sin ventas.
$labelsMeses = [];
$serieIngresos = [];
$serieCantidad = [];
$totalesPorMes = [];
foreach ($resumenMeses as $fila) {
    $totalesPorMes[$fila['mes']] = $fila;
}
for ($i = 5; $i >= 0; $i--) {
    $fechaMes = (new DateTimeImmutable('first day of this month'))->modify("-$i months");
    $claveMes = $fechaMes->format('Y-m');
    $labelsMeses[] = $fechaMes->format('m/Y');
    $serieIngresos[] = (float)($totalesPorMes[$claveMes]['ingresos'] ?? 0);
    $serieCantidad[] = (int)($totalesPorMes[$claveMes]['cantidad'] ?? 0);
}
$labelsPagos = array_map(static fn($f) => ucfirst(str_replace('_', ' ', $f['metodo'])), $resumenPagos);
$valoresPagos = array_map(static fn($f) => (int)$f['cantidad'], $resumenPagos);
$labelsTop = array_map(static fn($f) => $f['nombre'], $productosMasVendidos);
$valoresTop = array_map(static fn($f) => (int)$f['unidades'], $productosMasVendidos);

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
    <link rel="icon" type="image/jpeg" href="assets/logo-electrohogar.jpg?v=2">

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
            width: 48px;
            height: 48px;
            border-radius: 12px;
            display: grid;
            place-items: center;
            background: #fff;
            overflow: hidden;
            flex: 0 0 auto;
        }

        .logo-icono img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            display: block;
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
        /* Paneles de graficos integrados al estilo existente. */
        .graficos-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:22px; margin-bottom:26px; }
        .grafico-panel { background:white; border:1px solid var(--borde); border-radius:15px; padding:20px; min-width:0; box-shadow:0 3px 10px rgba(17,24,39,.04); }
        .grafico-panel h3 { font-size:16px; margin:0 0 5px; }
        .grafico-panel p { font-size:12px; color:var(--texto-suave); margin-bottom:17px; }
        .grafico-canvas {position:relative; height:260px; width:100%;}
        .grafico-canvas canvas{width:100%!important;height:100%!important;display:block}
        .mensaje-graficos { margin-bottom:18px; font-size:13px; color:#92400e; background:#fffbeb; border:1px solid #fde68a; padding:12px; border-radius:10px; display:none; }
        @media(max-width:1050px) { .graficos-grid {grid-template-columns:1fr;} }
    </style>
</head>
<body>

<div class="layout">

    <aside class="sidebar">
        <div class="logo">
            <div class="logo-icono"><img src="assets/logo-electrohogar.jpg?v=2" alt="Logo ElectroHogar"></div>
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

            <?php if($rolActual === 'admin' || $rolActual === 'vendedor'): ?>
                <a href="clientes.php">👥 <span>Clientes</span></a>
                <a href="ventas.php">🛒 <span>Ventas</span></a>
            <?php endif; ?>

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

            <section class="graficos-grid" aria-label="Estadisticas de ventas">
                <article class="grafico-panel">
                    <h3>Ingresos por mes</h3><p>Ingresos reales en soles de los últimos 6 meses</p>
                    <div class="grafico-canvas"><canvas id="chartIngresos"></canvas></div>
                </article>
                <article class="grafico-panel">
                    <h3>Cantidad de ventas por mes</h3><p>Evolución mensual de las ventas registradas</p>
                    <div class="grafico-canvas"><canvas id="chartCantidad"></canvas></div>
                </article>
                <article class="grafico-panel">
                    <h3>Métodos de pago</h3><p>Distribución según número de ventas</p>
                    <div class="grafico-canvas"><canvas id="chartPagos"></canvas></div>
                </article>
                <article class="grafico-panel">
                    <h3>Productos más vendidos</h3><p>Unidades vendidas por producto</p>
                    <div class="grafico-canvas"><canvas id="chartProductos"></canvas></div>
                </article>
            </section>
            <div class="mensaje-graficos" id="mensajeGraficos" role="status"></div>

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
                        <span>Según stock mínimo configurado</span>
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

<script>
(() => {
  'use strict';
  const months = <?= json_encode($labelsMeses, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG) ?>;
  const income = <?= json_encode($serieIngresos, JSON_NUMERIC_CHECK) ?>;
  const counts = <?= json_encode($serieCantidad, JSON_NUMERIC_CHECK) ?>;
  const payments = <?= json_encode($labelsPagos, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG) ?>;
  const payCounts = <?= json_encode($valoresPagos, JSON_NUMERIC_CHECK) ?>;
  const products = <?= json_encode($labelsTop, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG) ?>;
  const units = <?= json_encode($valoresTop, JSON_NUMERIC_CHECK) ?>;
  const palette = ['#2563eb','#16a34a','#f59e0b','#7c3aed','#06b6d4','#ef4444'];
  function setup(id) {
    const canvas = document.getElementById(id);
    const r = canvas.getBoundingClientRect();
    const w = Math.max(260, Math.round(r.width));
    const h = Math.max(220, Math.round(r.height));
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(w*dpr); canvas.height = Math.round(h*dpr);
    const ctx = canvas.getContext('2d'); ctx.scale(dpr,dpr);
    ctx.font='12px Segoe UI, Arial'; ctx.fillStyle='#64748b';
    return {ctx,w,h};
  }
  function label(ctx,text,x,y,align='center',color='#64748b') {
    ctx.textAlign=align; ctx.fillStyle=color;
    const str=String(text);
    ctx.fillText(str.length>19?str.slice(0,17)+'…':str,x,y);
  }
  function empty(ctx,w,h) {label(ctx,'Todavía no hay ventas registradas',w/2,h/2);}
  function graph(id, labels, values, type, color, money=false) {
    const {ctx,w,h}=setup(id);
    const vals=values.map(v=>Number(v)||0);
    if(!vals.length || vals.every(v=>v===0)){empty(ctx,w,h);return;}
    const left=money?70:46, right=20, top=22, bottom=49;
    const plotW=w-left-right, plotH=h-top-bottom;
    const topValue=Math.max(...vals,1)*1.15;
    ctx.strokeStyle='#e5e7eb';ctx.lineWidth=1;
    for(let i=0;i<=4;i++){
      const y=top+plotH*i/4;
      ctx.beginPath();ctx.moveTo(left,y);ctx.lineTo(w-right,y);ctx.stroke();
      const v=topValue*(1-i/4);
      label(ctx,money?'S/ '+Math.round(v).toLocaleString('es-PE'):Math.round(v),left-9,y+4,'right');
    }
    const span=plotW/vals.length;
    vals.forEach((v,i)=>{
      const x=left+span*(i+.5), y=top+plotH*(1-v/topValue);
      if(type==='bar'){
        ctx.fillStyle=color; const bw=Math.min(48,span*.55);
        ctx.fillRect(x-bw/2,y,bw,top+plotH-y);
      }
      const textoX = labels[i] || '';
      if(span < 82){
        ctx.save();
        ctx.translate(x,h-15);
        ctx.rotate(-0.42);
        ctx.textAlign='right';
        ctx.fillStyle='#64748b';
        ctx.font='11px Segoe UI, Arial';
        ctx.fillText(textoX,x*0,0);
        ctx.restore();
      }else{
        label(ctx,textoX,x,h-21);
      }
    });
    if(type==='line'){
      ctx.beginPath();ctx.strokeStyle=color;ctx.lineWidth=3;
      vals.forEach((v,i)=>{
        const x=left+span*(i+.5), y=top+plotH*(1-v/topValue);
        if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
      });ctx.stroke();
      vals.forEach((v,i)=>{
        const x=left+span*(i+.5),y=top+plotH*(1-v/topValue);
        ctx.beginPath();ctx.arc(x,y,4,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();
      });
    }
  }
  function donut(){
    const {ctx,w,h}=setup('chartPagos');
    const vals=payCounts.map(v=>Number(v)||0),total=vals.reduce((a,b)=>a+b,0);
    if(!total){empty(ctx,w,h);return;}
    const cx=w*.38,cy=h*.44,r=Math.min(h*.33,w*.23);
    let start=-Math.PI/2;
    vals.forEach((v,i)=>{
      const end=start+2*Math.PI*v/total;
      ctx.beginPath();ctx.arc(cx,cy,r,start,end);ctx.arc(cx,cy,r*.55,end,start,true);
      ctx.closePath();ctx.fillStyle=palette[i%palette.length];ctx.fill();start=end;
    });
    ctx.font='bold 20px Segoe UI, Arial'; label(ctx,total,cx,cy+6,'center','#111827');
    ctx.font='12px Segoe UI, Arial';
    payments.forEach((p,i)=>{
      const x=w*.66,y=30+i*23;
      if(y>h-10)return;
      ctx.fillStyle=palette[i%palette.length];ctx.fillRect(x,y-10,9,9);
      label(ctx,p+' ('+payCounts[i]+')',x+14,y-1,'left');
    });
  }
  function topProducts(){
    const {ctx,w,h}=setup('chartProductos');
    const vals=units.map(v=>Number(v)||0);
    if(!vals.length || vals.every(v=>v===0)){empty(ctx,w,h);return;}
    const max=Math.max(...vals,1),left=Math.min(145,w*.42),right=42,top=15;
    const rowH=Math.min(41,(h-25)/vals.length);
    vals.forEach((v,i)=>{
      const y=top+i*rowH;
      label(ctx,products[i],left-12,y+19,'right');
      ctx.fillStyle='#edf2f7';ctx.fillRect(left,y+5,w-left-right,21);
      ctx.fillStyle=palette[3];ctx.fillRect(left,y+5,(w-left-right)*v/max,21);
      label(ctx,v,w-right+8,y+20,'left','#111827');
    });
  }
  function render(){
    graph('chartIngresos',months,income,'bar',palette[0],true);
    graph('chartCantidad',months,counts,'line',palette[1]);
    donut();topProducts();
  }
  render();
  let resizeHandle;
  window.addEventListener('resize',()=>{clearTimeout(resizeHandle);resizeHandle=setTimeout(render,120);});
})();
</script>
</body>
</html>
