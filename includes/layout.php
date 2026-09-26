<?php
function app_top(string $titulo, string $activo = ''): void {
    $menu = [
        'dashboard' => ['📊','Dashboard','dashboard.php'],
        'productos' => ['📺','Productos','productos.php'],
        'categorias'=> ['🗂️','Categorías','categorias.php'],
        'clientes'  => ['👥','Clientes','clientes.php'],
        'ventas'    => ['🛒','Ventas','ventas.php'],
    ];
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($titulo) ?> | ElectroHogar</title>
    <link rel="stylesheet" href="assets/app.css">
</head>
<body>
<div class="layout">
    <aside class="sidebar">
        <div class="logo">
            <div class="logo-icono">⚡</div>
            <h2>ElectroHogar<span>Sistema de Ventas</span></h2>
        </div>
        <div class="menu-titulo">Menú principal</div>
        <nav class="menu">
            <?php foreach ($menu as $key => $item): ?>
                <a class="<?= $activo === $key ? 'activo' : '' ?>" href="<?= $item[2] ?>">
                    <?= $item[0] ?> <span><?= $item[1] ?></span>
                </a>
            <?php endforeach; ?>
        </nav>
    </aside>
    <section class="contenido">
        <header class="topbar">
            <div>
                <h1><?= htmlspecialchars($titulo) ?></h1>
                <p>Sistema de venta y control de electrodomésticos</p>
            </div>
            <div class="usuario">
                <div class="avatar">A</div>
                <div><strong>Administrador</strong><p>Panel principal</p></div>
            </div>
        </header>
        <main>
<?php
}
function app_bottom(): void {
?>
            <div class="pie">Sistema de Venta de Electrodomésticos · PHP + MySQL</div>
        </main>
    </section>
</div>
</body>
</html>
<?php } ?>