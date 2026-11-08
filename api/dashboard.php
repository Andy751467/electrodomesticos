<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";
if (!esta_logueado()) responder(false,"Debes iniciar sesión",null,401);
$db=(new Database())->getConnection();

$data=[
    "total_productos"=>(int)$db->query("SELECT COUNT(*) FROM productos WHERE estado=1")->fetchColumn(),
    "total_clientes"=>(int)$db->query("SELECT COUNT(*) FROM clientes")->fetchColumn(),
    "total_ventas"=>(int)$db->query("SELECT COUNT(*) FROM ventas")->fetchColumn(),
    "ingresos"=>(float)$db->query("SELECT COALESCE(SUM(total),0) FROM ventas")->fetchColumn(),
    "stock_bajo"=>(int)$db->query("SELECT COUNT(*) FROM productos WHERE stock<=stock_minimo AND estado=1")->fetchColumn()
];
$data["ultimas_ventas"]=$db->query("SELECT v.id,v.fecha,v.total,v.metodo_pago,CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,'')) cliente FROM ventas v LEFT JOIN clientes c ON c.id=v.cliente_id ORDER BY v.id DESC LIMIT 5")->fetchAll();

// Indicadores adicionales para el nuevo panel Flutter (consultas de lectura).
$data["ventas_mes"] = (int)$db->query(
    "SELECT COUNT(*) FROM ventas WHERE fecha >= DATE_FORMAT(CURDATE(), '%Y-%m-01')"
)->fetchColumn();
$data["ingresos_mes"] = (float)$db->query(
    "SELECT COALESCE(SUM(total),0) FROM ventas WHERE fecha >= DATE_FORMAT(CURDATE(), '%Y-%m-01')"
)->fetchColumn();
$data["ventas_meses"] = $db->query(
    "SELECT DATE_FORMAT(fecha,'%Y-%m') mes, COUNT(*) ventas, COALESCE(SUM(total),0) ingresos
     FROM ventas
     WHERE fecha >= DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 5 MONTH), '%Y-%m-01')
     GROUP BY DATE_FORMAT(fecha,'%Y-%m')
     ORDER BY mes"
)->fetchAll();
$data["metodos_pago"] = $db->query(
    "SELECT metodo_pago metodo, COUNT(*) cantidad FROM ventas
     GROUP BY metodo_pago ORDER BY cantidad DESC"
)->fetchAll();
$data["top_productos"] = $db->query(
    "SELECT p.nombre, COALESCE(SUM(d.cantidad),0) unidades
     FROM detalle_venta d INNER JOIN productos p ON p.id=d.producto_id
     GROUP BY p.id, p.nombre ORDER BY unidades DESC LIMIT 5"
)->fetchAll();

responder(true,"Resumen del dashboard",$data);
?>