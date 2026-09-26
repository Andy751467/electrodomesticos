<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';

if (esta_logueado()) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
$usuarioIngresado = '';

try {
    $dbRoles = (new Database())->getConnection();
    $dbRoles->exec("ALTER TABLE usuarios MODIFY rol ENUM('admin','vendedor','cliente') NOT NULL DEFAULT 'vendedor'");
    $stmtRol = $dbRoles->prepare("SELECT id,password FROM usuarios WHERE usuario='vendedor' LIMIT 1");
    $stmtRol->execute();
    $vendedorDefault = $stmtRol->fetch();

    $hashAnterior = '$2y$12$e3cFMGgW.tefvg.B3oSeTOmSlnyasAXOT57qjTcU9Xs40GKAYl9yC';

    if (!$vendedorDefault) {
        $hashVendedor = password_hash('vendedor123', PASSWORD_DEFAULT);
        $crearVendedor = $dbRoles->prepare("
            INSERT INTO usuarios(nombre,usuario,password,rol,estado)
            VALUES('Vendedor Principal','vendedor',?,'vendedor',1)
        ");
        $crearVendedor->execute([$hashVendedor]);
    } elseif ($vendedorDefault['password'] === $hashAnterior) {
        $hashVendedor = password_hash('vendedor123', PASSWORD_DEFAULT);
        $actualizarVendedor = $dbRoles->prepare("UPDATE usuarios SET password=?, rol='vendedor', estado=1 WHERE id=?");
        $actualizarVendedor->execute([$hashVendedor, (int)$vendedorDefault['id']]);
    }

    $stmtCliente = $dbRoles->prepare("SELECT id FROM usuarios WHERE usuario='cliente' LIMIT 1");
    $stmtCliente->execute();
    $clienteDefault = $stmtCliente->fetch();

    if (!$clienteDefault) {
        $hashCliente = password_hash('cliente123', PASSWORD_DEFAULT);
        $crearCliente = $dbRoles->prepare("
            INSERT INTO usuarios(nombre,usuario,password,rol,estado)
            VALUES('Cliente Demo','cliente',?,'cliente',1)
        ");
        $crearCliente->execute([$hashCliente]);
    }
} catch (Throwable $e) {
    // El login mostrará el error normal de conexión si MySQL no está disponible.
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $usuarioIngresado = trim($_POST['usuario'] ?? '');
    $password = (string)($_POST['password'] ?? '');

    if ($usuarioIngresado === '' || $password === '') {
        $error = 'Ingresa tu usuario y contraseña.';
    } else {
        try {
            $db = (new Database())->getConnection();

            $stmt = $db->prepare("
                SELECT id, nombre, usuario, password, rol, estado
                FROM usuarios
                WHERE usuario = ?
                LIMIT 1
            ");
            $stmt->execute([$usuarioIngresado]);
            $user = $stmt->fetch();

            if (!$user || (int)$user['estado'] !== 1 || !password_verify($password, $user['password'])) {
                $error = 'Usuario o contraseña incorrectos.';
            } else {
                session_regenerate_id(true);

                $_SESSION['usuario'] = [
                    'id' => (int)$user['id'],
                    'nombre' => $user['nombre'],
                    'usuario' => $user['usuario'],
                    'rol' => $user['rol']
                ];

                $next = $_POST['next'] ?? '';
                if ($next !== '' && preg_match('/^[a-zA-Z0-9_\-.?=&]+$/', $next)) {
                    header('Location: ' . $next);
                } else {
                    header('Location: dashboard.php');
                }
                exit;
            }
        } catch (Throwable $e) {
            $error = 'No se pudo iniciar sesión. Verifica que MySQL esté encendido.';
        }
    }
}

$next = $_GET['next'] ?? '';
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Iniciar sesión | ElectroHogar</title>
    <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{
            font-family:"Segoe UI",Arial,sans-serif;
            min-height:100vh;
            display:grid;
            place-items:center;
            background:
                radial-gradient(circle at 20% 20%,rgba(37,99,235,.18),transparent 35%),
                radial-gradient(circle at 80% 80%,rgba(124,58,237,.14),transparent 35%),
                #f3f4f6;
            color:#111827;
            padding:24px;
        }
        .login{
            width:100%;
            max-width:420px;
            background:#fff;
            border:1px solid #e5e7eb;
            border-radius:22px;
            box-shadow:0 24px 60px rgba(17,24,39,.12);
            overflow:hidden;
        }
        .brand{
            background:#111827;
            color:#fff;
            padding:30px;
            text-align:center;
        }
        .icon{
            width:58px;height:58px;border-radius:16px;
            display:grid;place-items:center;
            margin:0 auto 14px;
            background:#2563eb;font-size:28px;
        }
        .brand h1{font-size:24px}
        .brand p{color:#cbd5e1;margin-top:6px;font-size:13px}
        .body{padding:30px}
        .body h2{font-size:20px;margin-bottom:6px}
        .sub{color:#6b7280;font-size:13px;margin-bottom:22px}
        label{display:block;font-size:12px;font-weight:700;color:#4b5563;margin:0 0 7px}
        input{
            width:100%;padding:12px 13px;border:1px solid #d1d5db;
            border-radius:10px;font:inherit;outline:none;margin-bottom:16px;
        }
        input:focus{border-color:#60a5fa;box-shadow:0 0 0 3px #dbeafe}
        .password-wrap{position:relative}
        .password-wrap input{padding-right:48px}
        .toggle{
            position:absolute;right:10px;top:8px;border:0;background:transparent;
            cursor:pointer;font-size:18px;padding:4px;
        }
        .btn{
            width:100%;border:0;border-radius:10px;padding:12px;
            background:#2563eb;color:#fff;font-weight:700;font-size:14px;cursor:pointer;
        }
        .btn:hover{background:#1d4ed8}
        .error{
            background:#fef2f2;border:1px solid #fecaca;color:#991b1b;
            padding:11px 12px;border-radius:9px;margin-bottom:16px;font-size:13px;
        }
        .demo{
            margin-top:18px;padding:12px;border-radius:10px;background:#f8fafc;
            border:1px solid #e5e7eb;color:#475569;font-size:12px;line-height:1.6
        }
    </style>
</head>
<body>
<div class="login">
    <div class="brand">
        <div class="icon">⚡</div>
        <h1>ElectroHogar</h1>
        <p>Sistema de Ventas e Inventario</p>
    </div>

    <div class="body">
        <h2>Iniciar sesión</h2>
        <p class="sub">Ingresa tus credenciales para acceder al sistema.</p>

        <?php if ($error): ?>
            <div class="error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="post">
            <input type="hidden" name="next" value="<?= htmlspecialchars($next) ?>">

            <label>Usuario</label>
            <input
                type="text"
                name="usuario"
                autocomplete="username"
                required
                autofocus
                value="<?= htmlspecialchars($usuarioIngresado) ?>"
                placeholder="Ej. admin"
            >

            <label>Contraseña</label>
            <div class="password-wrap">
                <input
                    id="password"
                    type="password"
                    name="password"
                    autocomplete="current-password"
                    required
                    placeholder="Ingresa tu contraseña"
                >
                <button class="toggle" type="button" onclick="togglePassword()" title="Mostrar u ocultar contraseña">👁️</button>
            </div>

            <button class="btn" type="submit">Ingresar</button>
        </form>

        <div class="demo">
            <strong>Accesos de prueba:</strong><br>
            Administrador: <strong>admin</strong> / <strong>admin123</strong><br>
            Vendedor: <strong>vendedor</strong> / <strong>vendedor123</strong><br>
            Cliente: <strong>cliente</strong> / <strong>cliente123</strong>
        </div>
    </div>
</div>

<script>
function togglePassword(){
    const input = document.getElementById('password');
    input.type = input.type === 'password' ? 'text' : 'password';
}
</script>
</body>
</html>