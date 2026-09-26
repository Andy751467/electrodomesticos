<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";
if (!esta_logueado()) responder(false,"Debes iniciar sesión",null,401);
if (!in_array(rol_actual(), ["admin","vendedor"], true)) responder(false,"No tienes permiso para esta API",null,403);
$db=(new Database())->getConnection();
$method=$_SERVER["REQUEST_METHOD"];

if($method==="GET"){
    if(isset($_GET["id"])){
        $id=(int)$_GET["id"];
        $s=$db->prepare("SELECT v.*,CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,'')) cliente,u.nombre vendedor FROM ventas v LEFT JOIN clientes c ON c.id=v.cliente_id LEFT JOIN usuarios u ON u.id=v.usuario_id WHERE v.id=?");
        $s->execute([$id]); $venta=$s->fetch();
        if(!$venta) responder(false,"Venta no encontrada",null,404);
        $s2=$db->prepare("SELECT dv.*,p.nombre producto,p.marca FROM detalle_venta dv JOIN productos p ON p.id=dv.producto_id WHERE dv.venta_id=?");
        $s2->execute([$id]); $venta["detalle"]=$s2->fetchAll();
        responder(true,"Detalle de venta",$venta);
    }
    responder(true,"Lista de ventas",$db->query("SELECT v.id,v.fecha,v.total,v.metodo_pago,CONCAT(COALESCE(c.nombres,''),' ',COALESCE(c.apellidos,'')) cliente,u.nombre vendedor FROM ventas v LEFT JOIN clientes c ON c.id=v.cliente_id LEFT JOIN usuarios u ON u.id=v.usuario_id ORDER BY v.id DESC")->fetchAll());
}

if($method==="POST"){
    $d=jsonInput(); requerido($d,["usuario_id","metodo_pago","detalle"]);
    if(!is_array($d["detalle"]) || count($d["detalle"])===0) responder(false,"La venta debe contener productos",null,422);
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
        $s->execute([!empty($d["cliente_id"])?(int)$d["cliente_id"]:null,(int)$d["usuario_id"],$total,$d["metodo_pago"],$d["observacion"]??null]);
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