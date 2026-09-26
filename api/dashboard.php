<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
$db=(new Database())->getConnection();

$data=[
    "total_productos"=>(int)$db->query("SELECT COUNT(*) FROM productos WHERE estado=1")->fetchColumn(),
    "total_clientes"=>(int)$db->query("SELECT COUNT(*) FROM clientes")->fetchColumn(),
    "total_ventas"=>(int)$db->query("SELECT COUNT(*) FROM ventas")->fetchColumn(),
    "ingresos"=>(float)$db->query("SELECT COALESCE(SUM(total),0) FROM ventas")->fetchColumn(),
    "stock_bajo"=>(int)$db->query("SELECT COUNT(*) FROM productos WHERE stock<=5 AND estado=1")->fetchColumn()
];
$data["ultimas_ventas"]=$db->query("SELECT v.id,v.fecha,v.total,v.metodo_pago,CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,'')) cliente FROM ventas v LEFT JOIN clientes c ON c.id=v.cliente_id ORDER BY v.id DESC LIMIT 5")->fetchAll();
responder(true,"Resumen del dashboard",$data);
?>