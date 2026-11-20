<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";
if (!esta_logueado()) responder(false,"Debes iniciar sesión",null,401);
if (!in_array(rol_actual(), ["admin","vendedor"], true)) responder(false,"No tienes permiso para esta API",null,403);
$db=(new Database())->getConnection();
$method=$_SERVER["REQUEST_METHOD"];

if($method==="GET"){
    // Incluir el nombre del comprador de pedidos móviles: sus ventas no
    // tienen cliente_id en la tabla clientes, pero sí un pedido vinculado.
    $datosVenta = "
        SELECT v.id, v.fecha, v.total, v.metodo_pago, v.observacion,
               COALESCE(
                 NULLIF(TRIM(CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,''))), ''),
                 NULLIF(TRIM(uc.nombre), ''),
                 'Sin cliente asignado'
               ) AS cliente,
               c.dni AS dni_cliente,
               u.nombre AS vendedor
        FROM ventas v
        LEFT JOIN clientes c ON c.id=v.cliente_id
        LEFT JOIN usuarios u ON u.id=v.usuario_id
        LEFT JOIN pedidos_cliente pc ON pc.venta_id=v.id
        LEFT JOIN usuarios uc ON uc.id=pc.usuario_id
    ";

    if (isset($_GET["id"])) {
        $valor = $_GET["id"];
        if (!is_scalar($valor) ||
            !preg_match('/^[1-9][0-9]*$/D', (string)$valor)) {
            responder(false, "Identificador de venta inválido", null, 422);
        }
        $id = (int)$valor;
        $detalleSql = "
            SELECT v.*, COALESCE(
                NULLIF(TRIM(CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,''))), ''),
                NULLIF(TRIM(uc.nombre), ''),
                'Sin cliente asignado'
            ) AS cliente, u.nombre AS vendedor
            FROM ventas v
            LEFT JOIN clientes c ON c.id=v.cliente_id
            LEFT JOIN usuarios u ON u.id=v.usuario_id
            LEFT JOIN pedidos_cliente pc ON pc.venta_id=v.id
            LEFT JOIN usuarios uc ON uc.id=pc.usuario_id
            WHERE v.id=?
        ";
        $stmt = $db->prepare($detalleSql);
        $stmt->execute([$id]);
        $venta = $stmt->fetch();
        if (!$venta) responder(false,"Venta no encontrada",null,404);
        $items = $db->prepare(
            "SELECT dv.*,p.nombre producto,p.marca
             FROM detalle_venta dv
             JOIN productos p ON p.id=dv.producto_id
             WHERE dv.venta_id=?"
        );
        $items->execute([$id]);
        $venta["detalle"] = $items->fetchAll();
        responder(true,"Detalle de venta",$venta);
    }

    $desde = trim((string)($_GET['desde'] ?? ''));
    $hasta = trim((string)($_GET['hasta'] ?? ''));
    $cliente = trim((string)($_GET['cliente'] ?? ''));
    $metodo = trim((string)($_GET['metodo_pago'] ?? ''));

    foreach (['desde' => $desde, 'hasta' => $hasta] as $nombre => $fecha) {
        if ($fecha !== '') {
            $obj = DateTimeImmutable::createFromFormat('!Y-m-d', $fecha);
            if (!$obj || $obj->format('Y-m-d') !== $fecha) {
                responder(false, "La fecha $nombre debe tener el formato AAAA-MM-DD", null, 422);
            }
        }
    }
    if ($desde !== '' && $hasta !== '' && $desde > $hasta) {
        responder(false, "La fecha inicial no puede ser posterior a la final", null, 422);
    }
    if (strlen($cliente) > 100) {
        responder(false, "La búsqueda de cliente admite hasta 100 caracteres", null, 422);
    }
    if ($metodo !== '' &&
        !in_array($metodo, ['efectivo','yape','plin','tarjeta','transferencia'], true)) {
        responder(false, "Método de pago inválido", null, 422);
    }

    $condiciones = [];
    $valores = [];
    if ($desde !== '') {
        $condiciones[] = "v.fecha >= ?";
        $valores[] = $desde;
    }
    if ($hasta !== '') {
        // Incluir las ventas de todo el día, incluso las de las 23:59.
        $condiciones[] = "v.fecha < DATE_ADD(?, INTERVAL 1 DAY)";
        $valores[] = $hasta;
    }
    if ($cliente !== '') {
        $condiciones[] = "(
            CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,'')) LIKE ?
            OR c.dni LIKE ? OR uc.nombre LIKE ? OR uc.usuario LIKE ?
        )";
        $busqueda = '%'.$cliente.'%';
        array_push($valores, $busqueda, $busqueda, $busqueda, $busqueda);
    }
    if ($metodo !== '') {
        $condiciones[] = "v.metodo_pago = ?";
        $valores[] = $metodo;
    }

    $sql = $datosVenta;
    if ($condiciones) $sql .= " WHERE ".implode(" AND ", $condiciones);
    $sql .= " ORDER BY v.fecha DESC,v.id DESC";
    $stmt = $db->prepare($sql);
    $stmt->execute($valores);
    responder(true, "Lista de ventas", $stmt->fetchAll());
}

if($method==="POST"){
    $d=jsonInput(); requerido($d,["metodo_pago","detalle"]);
    if(!is_array($d["detalle"]) || count($d["detalle"])===0) responder(false,"La venta debe contener productos",null,422);
    $usuarioId = (int)(usuario_actual()["id"] ?? 0);
    if ($usuarioId <= 0) responder(false,"Sesión no válida",null,401);
    if (!in_array($d["metodo_pago"], ["efectivo","yape","plin","tarjeta","transferencia"],true)) responder(false,"Método de pago inválido",null,422);
    try{
        $db->beginTransaction();
        $total=0; $items=[];
        foreach($d["detalle"] as $it){
            if(!isset($it["producto_id"],$it["cantidad"])) throw new Exception("Cada detalle debe tener producto_id y cantidad");
            $pid=(int)$it["producto_id"]; $cant=(int)$it["cantidad"];
            if($cant<=0) throw new Exception("La cantidad debe ser mayor a 0");
            $s=$db->prepare("SELECT id,nombre,precio,stock,estado FROM productos WHERE id=? FOR UPDATE");
            $s->execute([$pid]); $p=$s->fetch();
            if(!$p || (int)$p["estado"]!==1) throw new Exception("Producto no disponible");
            if((int)$p["stock"]<$cant) throw new Exception("Stock insuficiente para ".$p["nombre"]);
            $precio=(float)$p["precio"]; $sub=$precio*$cant; $total+=$sub;
            $items[]=["producto_id"=>$pid,"cantidad"=>$cant,"precio"=>$precio,"subtotal"=>$sub];
        }
        $s=$db->prepare("INSERT INTO ventas(cliente_id,usuario_id,fecha,total,metodo_pago,observacion) VALUES(?,?,NOW(),?,?,?)");
        $s->execute([!empty($d["cliente_id"])?(int)$d["cliente_id"]:null,$usuarioId,$total,$d["metodo_pago"],$d["observacion"]??null]);
        $vid=(int)$db->lastInsertId();
        $sd=$db->prepare("INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal) VALUES(?,?,?,?,?)");
        $ss=$db->prepare("UPDATE productos SET stock=stock-? WHERE id=?");
        foreach($items as $it){
            $sd->execute([$vid,$it["producto_id"],$it["cantidad"],$it["precio"],$it["subtotal"]]);
            $ss->execute([$it["cantidad"],$it["producto_id"]]);
        }
        $db->commit();
        responder(true,"Venta registrada correctamente",["venta_id"=>$vid,"total"=>round($total,2)],201);
    }catch(Throwable $e){
        if($db->inTransaction()) $db->rollBack();
        responder(false,$e->getMessage(),null,422);
    }
}
responder(false,"Método no permitido",null,405);
?>