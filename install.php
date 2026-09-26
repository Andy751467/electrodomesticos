<?php
$host = "localhost";
$user = "root";
$pass = "";
$dbname = "venta_electrodomesticos";

try {
    $pdo = new PDO(
        "mysql:host={$host};charset=utf8mb4",
        $user,
        $pass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );

    $pdo->exec("CREATE DATABASE IF NOT EXISTS {$dbname} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdo->exec("USE {$dbname}");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS usuarios (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nombre VARCHAR(100) NOT NULL,
            usuario VARCHAR(50) NOT NULL UNIQUE,
            password VARCHAR(255) NOT NULL,
            rol ENUM('admin','vendedor') NOT NULL DEFAULT 'vendedor',
            estado TINYINT(1) NOT NULL DEFAULT 1,
            creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS categorias (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nombre VARCHAR(100) NOT NULL UNIQUE,
            descripcion VARCHAR(255) NULL,
            creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS productos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            categoria_id INT NOT NULL,
            nombre VARCHAR(120) NOT NULL,
            marca VARCHAR(80) NOT NULL,
            modelo VARCHAR(80) NULL,
            precio DECIMAL(10,2) NOT NULL DEFAULT 0,
            stock INT NOT NULL DEFAULT 0,
            descripcion TEXT NULL,
            imagen VARCHAR(255) NULL,
            estado TINYINT(1) NOT NULL DEFAULT 1,
            creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT fk_producto_categoria
                FOREIGN KEY (categoria_id) REFERENCES categorias(id)
        ) ENGINE=InnoDB
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS clientes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nombres VARCHAR(100) NOT NULL,
            apellidos VARCHAR(100) NULL,
            dni VARCHAR(15) NULL UNIQUE,
            telefono VARCHAR(20) NULL,
            email VARCHAR(120) NULL,
            direccion VARCHAR(200) NULL,
            creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS ventas (
            id INT AUTO_INCREMENT PRIMARY KEY,
            cliente_id INT NULL,
            usuario_id INT NOT NULL,
            fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            total DECIMAL(12,2) NOT NULL DEFAULT 0,
            metodo_pago ENUM('efectivo','yape','plin','tarjeta','transferencia') NOT NULL,
            observacion VARCHAR(255) NULL,
            CONSTRAINT fk_venta_cliente
                FOREIGN KEY (cliente_id) REFERENCES clientes(id),
            CONSTRAINT fk_venta_usuario
                FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        ) ENGINE=InnoDB
    ");

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS detalle_venta (
            id INT AUTO_INCREMENT PRIMARY KEY,
            venta_id INT NOT NULL,
            producto_id INT NOT NULL,
            cantidad INT NOT NULL,
            precio_unitario DECIMAL(10,2) NOT NULL,
            subtotal DECIMAL(12,2) NOT NULL,
            CONSTRAINT fk_detalle_venta
                FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
            CONSTRAINT fk_detalle_producto
                FOREIGN KEY (producto_id) REFERENCES productos(id)
        ) ENGINE=InnoDB
    ");

    $categorias = [
        ['Televisores','Smart TV y televisores'],
        ['Refrigeradoras','Refrigeradoras y congeladoras'],
        ['Cocina','Cocinas, hornos y microondas'],
        ['Lavado','Lavadoras y secadoras'],
        ['Pequeños electrodomésticos','Licuadoras, planchas y otros']
    ];

    $stmt = $pdo->prepare("INSERT IGNORE INTO categorias(nombre, descripcion) VALUES(?, ?)");
    foreach ($categorias as $c) {
        $stmt->execute($c);
    }

    $cantidadProductos = (int)$pdo->query("SELECT COUNT(*) FROM productos")->fetchColumn();
    if ($cantidadProductos === 0) {
        $pdo->exec("
            INSERT INTO productos(categoria_id,nombre,marca,modelo,precio,stock,descripcion) VALUES
            (1,'Smart TV 50 pulgadas','Samsung','UN50',1699.90,10,'Televisor Smart 4K'),
            (2,'Refrigeradora No Frost','LG','GT32',2199.00,6,'Refrigeradora 2 puertas'),
            (3,'Microondas 20L','Oster','OGM20',399.90,15,'Microondas digital'),
            (4,'Lavadora 15Kg','Mabe','LMA15',1499.00,7,'Lavadora automática'),
            (5,'Licuadora 1.5L','Oster','BLSTK',289.90,4,'Licuadora de vidrio')
        ");
    }

    $cantidadClientes = (int)$pdo->query("SELECT COUNT(*) FROM clientes")->fetchColumn();
    if ($cantidadClientes === 0) {
        $pdo->exec("
            INSERT INTO clientes(nombres,apellidos,dni,telefono,email,direccion) VALUES
            ('Carlos','Ramirez','70000001','999111222','carlos@gmail.com','Pucallpa'),
            ('Ana','Torres','70000002','999333444','ana@gmail.com','Yarinacocha')
        ");
    }

    $stmtUsuario = $pdo->prepare("SELECT COUNT(*) FROM usuarios WHERE usuario = ?");
    $stmtUsuario->execute(['admin']);
    if ((int)$stmtUsuario->fetchColumn() === 0) {
        $hash = password_hash('admin123', PASSWORD_DEFAULT);
        $stmtInsertUsuario = $pdo->prepare("
            INSERT INTO usuarios(nombre,usuario,password,rol,estado)
            VALUES(?,?,?,?,1)
        ");
        $stmtInsertUsuario->execute(['Administrador','admin',$hash,'admin']);
    }

    $stmtVendedor = $pdo->prepare("SELECT COUNT(*) FROM usuarios WHERE usuario = ?");
    $stmtVendedor->execute(['vendedor']);
    if ((int)$stmtVendedor->fetchColumn() === 0) {
        $hashVendedor = password_hash('vendedor123', PASSWORD_DEFAULT);
        $stmtInsertVendedor = $pdo->prepare("
            INSERT INTO usuarios(nombre,usuario,password,rol,estado)
            VALUES(?,?,?,?,1)
        ");
        $stmtInsertVendedor->execute(['Vendedor Principal','vendedor',$hashVendedor,'vendedor']);
    }

    $cantidadVentas = (int)$pdo->query("SELECT COUNT(*) FROM ventas")->fetchColumn();
    if ($cantidadVentas === 0) {
        $pdo->beginTransaction();

        $pdo->exec("
            INSERT INTO ventas(cliente_id,usuario_id,fecha,total,metodo_pago,observacion)
            VALUES
            (1,1,NOW(),1699.90,'yape','Venta inicial de demostración'),
            (2,1,NOW(),689.80,'efectivo','Venta inicial de demostración')
        ");

        $venta1 = (int)$pdo->query("SELECT MIN(id) FROM ventas")->fetchColumn();
        $venta2 = $venta1 + 1;

        $pdo->prepare("
            INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal)
            VALUES(?,?,?,?,?)
        ")->execute([$venta1,1,1,1699.90,1699.90]);

        $pdo->prepare("
            INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal)
            VALUES(?,?,?,?,?)
        ")->execute([$venta2,3,1,399.90,399.90]);

        $pdo->prepare("
            INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal)
            VALUES(?,?,?,?,?)
        ")->execute([$venta2,5,1,289.90,289.90]);

        $pdo->exec("UPDATE productos SET stock = stock - 1 WHERE id IN (1,3,5)");

        $pdo->commit();
    }

    header("Location: login.php");
    exit;

} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    http_response_code(500);
    ?>
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <title>Error de instalación</title>
        <style>
            body{font-family:Segoe UI,Arial,sans-serif;background:#f3f4f6;padding:40px}
            .box{max-width:760px;margin:auto;background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:24px}
            h2{color:#b91c1c}
            code{background:#f3f4f6;padding:3px 6px;border-radius:5px}
        </style>
    </head>
    <body>
        <div class="box">
            <h2>No se pudo preparar la base de datos</h2>
            <p>Verifica que <strong>MySQL esté encendido en XAMPP</strong>.</p>
            <p><strong>Detalle:</strong> <?= htmlspecialchars($e->getMessage()) ?></p>
            <p>Luego vuelve a abrir <code>http://localhost/electrodomesticos/</code></p>
        </div>
    </body>
    </html>
    <?php
}
?>