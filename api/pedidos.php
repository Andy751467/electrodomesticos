<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../config/auth.php';

if (!esta_logueado()) responder(false, "Debes iniciar sesión", null, 401);
$uid = (int) usuario_actual()['id'];
$cliente = es_cliente();
$personal = in_array(rol_actual(), ['admin', 'vendedor'], true);
if (!$cliente && !$personal) responder(false, "Acceso denegado", null, 403);
$method = $_SERVER['REQUEST_METHOD'];
if ($method !== 'GET' && stripos($_SERVER['CONTENT_TYPE'] ?? '', 'application/json') !== 0) {
    responder(false, "Se requiere una petición JSON", null, 415);
}

function pedidoError(string $mensaje): void { throw new DomainException($mensaje); }
function dineroCentavos($v): int { return (int) round((float)$v * 100); }
function importePedido(int $c): string { return number_format($c / 100, 2, '.', ''); }

try {
    $db = (new Database())->getConnection();

    if ($method === 'GET') {
        $sql = "SELECT p.id,p.metodo_pago,p.referencia,p.total,p.estado,p.fecha,
                       p.fecha_revision,p.venta_id,u.nombre cliente
                FROM pedidos_cliente p JOIN usuarios u ON u.id=p.usuario_id";
        if ($cliente) $sql .= " WHERE p.usuario_id=?";
        // Pendientes primero para facilitar su revisión.
        $sql .= " ORDER BY " . ($personal ? "(p.estado='pendiente') DESC," : "") . "p.id DESC LIMIT 100";
        $s = $db->prepare($sql);
        $s->execute($cliente ? [$uid] : []);
        $pedidos = $s->fetchAll();
        $d = $db->prepare("SELECT producto_id,nombre,cantidad,precio_unitario,subtotal
                            FROM detalle_pedido_cliente WHERE pedido_id=? ORDER BY producto_id");
        foreach ($pedidos as &$p) {
            $d->execute([$p['id']]);
            $p['detalle'] = $d->fetchAll();
        }
        unset($p);
        responder(true, "Pedidos", $pedidos);
    }

    if ($method === 'POST') {
        if (!$cliente) responder(false, "Solo las cuentas cliente realizan pedidos", null, 403);
        $d = jsonInput();
        $metodo = $d['metodo_pago'] ?? '';
        $clave = $d['clave_peticion'] ?? '';
        $ref = $d['referencia'] ?? '';
        if (!is_string($metodo) || !in_array($metodo, ['efectivo','yape','plin','transferencia'], true)
            || !is_string($clave) || !preg_match('/^[a-f0-9]{32}$/D', $clave)
            || !is_string($ref) || strlen($ref) > 120) pedidoError("Método o referencia inválidos");
        $ref = trim($ref);
        // La referencia es informativa; jamás acredita un pago.
        $items = $d['detalle'] ?? null;
        if (!is_array($items) || count($items) < 1 || count($items) > 100) pedidoError("Carrito inválido");
        $cantidades = [];
        foreach ($items as $item) {
            if (!is_array($item)) pedidoError("Detalle inválido");
            $pid = $item['producto_id'] ?? null;
            $n = $item['cantidad'] ?? null;
            if (!is_int($pid) || $pid < 1 || !is_int($n) || $n < 1 || $n > 99 || isset($cantidades[$pid])) pedidoError("Cantidad o producto inválido");
            $cantidades[$pid] = $n;
        }
        ksort($cantidades);
        $esperado = $d['total_centavos'] ?? null;
        if (!is_int($esperado) || $esperado < 0) pedidoError("Total inválido");

        $db->beginTransaction();
        $buscar = $db->prepare("SELECT id,total,estado FROM pedidos_cliente WHERE usuario_id=? AND clave_peticion=?");
        $buscar->execute([$uid,$clave]);
        if ($previo = $buscar->fetch()) {
            $db->commit();
            responder(true, "Pedido ya registrado", $previo, 200);
        }
        $s = $db->prepare("SELECT id,nombre,precio,stock,estado FROM productos WHERE id=? FOR UPDATE");
        $lineas = []; $total = 0;
        foreach ($cantidades as $pid => $n) {
            $s->execute([$pid]); $p=$s->fetch();
            if (!$p || (int)$p['estado'] !== 1) pedidoError("Un producto ya no está disponible");
            if ((int)$p['stock'] < $n) pedidoError("Stock insuficiente: ".$p['nombre']);
            $precio = dineroCentavos($p['precio']);
            if ($precio < 0) pedidoError("Precio inválido");
            $sub = $precio*$n; $total += $sub;
            if ($total > 999999999999) pedidoError("El total excede el límite");
            $lineas[] = [$pid,$p['nombre'],$n,importePedido($precio),importePedido($sub)];
        }
        if ($total !== $esperado) pedidoError("Los precios cambiaron. Actualiza el catálogo antes de confirmar.");
        $ins = $db->prepare("INSERT INTO pedidos_cliente(usuario_id,clave_peticion,metodo_pago,referencia,total)
                            VALUES(?,?,?,?,?)");
        try {
            $ins->execute([$uid,$clave,$metodo,$ref === '' ? null : $ref,importePedido($total)]);
        } catch (PDOException $e) {
            if ((string)$e->getCode() !== '23000') throw $e;
            $db->rollBack();
            $buscar->execute([$uid,$clave]);
            if ($previo = $buscar->fetch()) responder(true, "Pedido ya registrado", $previo, 200);
            throw $e;
        }
        $id = (int)$db->lastInsertId();
        $ins = $db->prepare("INSERT INTO detalle_pedido_cliente(pedido_id,producto_id,nombre,cantidad,precio_unitario,subtotal) VALUES(?,?,?,?,?,?)");
        foreach ($lineas as $l) $ins->execute(array_merge([$id],$l));
        $db->commit();
        responder(true,"Pedido registrado; pago pendiente de verificación", ["id"=>$id,"total"=>importePedido($total),"estado"=>"pendiente"],201);
    }

    if ($method === 'PUT') {
        if (!$personal) responder(false,"No tienes permiso para verificar pagos",null,403);
        $d=jsonInput(); $id=$d['id'] ?? null; $accion=$d['accion'] ?? '';
        if (!is_int($id) || $id < 1 || !in_array($accion,['confirmar','rechazar'],true)) pedidoError("Solicitud inválida");
        $db->beginTransaction();
        $s=$db->prepare("SELECT * FROM pedidos_cliente WHERE id=? FOR UPDATE");
        $s->execute([$id]); $p=$s->fetch();
        if (!$p || $p['estado'] !== 'pendiente') pedidoError("El pedido no está pendiente");
        $ventaId=null;
        if ($accion === 'confirmar') {
            // Solo el personal que verificó el dinero puede confirmar la venta.
            $s=$db->prepare("SELECT * FROM detalle_pedido_cliente WHERE pedido_id=? ORDER BY producto_id");
            $s->execute([$id]); $items=$s->fetchAll();
            if (!$items) pedidoError("El pedido no tiene productos");
            $stock=$db->prepare("SELECT stock,estado FROM productos WHERE id=? FOR UPDATE");
            foreach ($items as $it) {
                $stock->execute([$it['producto_id']]); $actual=$stock->fetch();
                if (!$actual || (int)$actual['estado'] !== 1 || (int)$actual['stock'] < (int)$it['cantidad']) {
                    pedidoError("Stock insuficiente: ".$it['nombre'].". No se registró la venta.");
                }
            }
            $s=$db->prepare("INSERT INTO ventas(cliente_id,usuario_id,fecha,total,metodo_pago,observacion) VALUES(NULL,?,NOW(),?,?,?)");
            $s->execute([$uid,$p['total'],$p['metodo_pago'],"Pedido móvil #".$id]);
            $ventaId=(int)$db->lastInsertId();
            $line=$db->prepare("INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal) VALUES(?,?,?,?,?)");
            $bajar=$db->prepare("UPDATE productos SET stock=stock-? WHERE id=?");
            foreach ($items as $it) {
                $line->execute([$ventaId,$it['producto_id'],$it['cantidad'],$it['precio_unitario'],$it['subtotal']]);
                $bajar->execute([$it['cantidad'],$it['producto_id']]);
            }
        }
        $estado=$accion==='confirmar'?'confirmado':'rechazado';
        $s=$db->prepare("UPDATE pedidos_cliente SET estado=?,verificado_por=?,fecha_revision=NOW(),venta_id=? WHERE id=?");
        $s->execute([$estado,$uid,$ventaId,$id]);
        $db->commit();
        responder(true,$accion==='confirmar'?"Pago verificado y venta registrada":"Pedido rechazado",["id"=>$id,"estado"=>$estado,"venta_id"=>$ventaId]);
    }
    responder(false,"Método no permitido",null,405);
} catch (DomainException $e) {
    if (isset($db) && $db->inTransaction()) $db->rollBack();
    responder(false,$e->getMessage(),null,422);
} catch (Throwable $e) {
    if (isset($db) && $db->inTransaction()) $db->rollBack();
    error_log('ElectroHogar pedidos: '.$e->getMessage());
    responder(false,"No se pudo procesar el pedido. Verifica MySQL y la migración de pedidos.",null,500);
}
