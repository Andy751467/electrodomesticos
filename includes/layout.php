<?php
require_once __DIR__ . '/../config/auth.php';
require_login();

function app_top(string $titulo, string $activo = ''): void {
    $u = usuario_actual();
    $rol = $u['rol'] ?? '';

    $menu = [
        'dashboard' => ['📊','Dashboard','dashboard.php',['admin','vendedor']],
        'productos' => ['📺','Productos','productos.php',['admin','vendedor']],
        'categorias'=> ['🗂️','Categorías','categorias.php',['admin']],
        'clientes'  => ['👥','Clientes','clientes.php',['admin','vendedor']],
        'ventas'    => ['🛒','Ventas','ventas.php',['admin','vendedor']],
        'usuarios'  => ['🔐','Usuarios','usuarios.php',['admin']],
        'respaldo'  => ['💾','Respaldo BD','respaldo.php',['admin']],
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
                <?php if (!in_array($rol, $item[3], true)) continue; ?>
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
                <div class="avatar"><?= htmlspecialchars(strtoupper(substr($u['nombre'] ?? 'U',0,1))) ?></div>
                <div>
                    <strong><?= htmlspecialchars($u['nombre'] ?? 'Usuario') ?></strong>
                    <p>
                        <?= htmlspecialchars(ucfirst($rol)) ?>
                        ·
                        <a href="logout.php" style="color:#dc2626;text-decoration:none">Cerrar sesión</a>
                    </p>
                </div>
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