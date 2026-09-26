<?php
header("Content-Type: application/json; charset=UTF-8");
echo json_encode([
    "ok" => true,
    "sistema" => "Backend de Venta de Electrodomésticos",
    "version" => "1.0",
    "endpoints" => [
        "POST api/login.php",
        "GET/POST/PUT/DELETE api/categorias.php",
        "GET/POST/PUT/DELETE api/productos.php",
        "GET/POST/PUT/DELETE api/clientes.php",
        "GET/POST api/ventas.php",
        "GET api/dashboard.php"
    ]
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
?>