<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/includes/layout.php';
$db=(new Database())->getConnection();
$mensaje=$error='';

if($_SERVER['REQUEST_METHOD']==='POST' && ($_POST['accion']??'')==='vender'){
    try{
        $clienteId=(int)($_POST['cliente_id']??0);
        $metodo=$_POST['metodo_pago']??'efectivo';
        $productos=$_POST['producto_id']??[];
        $cantidades=$_POST['cantidad']??[];
        $permitidos=['efectivo','yape','plin','tarjeta','transferencia'];
        if(!in_array($metodo,$permitidos,true)) throw new Exception('Método de pago inválido.');
        if(!$productos) throw new Exception('Agrega por lo menos un producto.');
        $db->beginTransaction();
        $total=0;$items=[];
        foreach($productos as $i=>$pidRaw){
            $pid=(int)$pidRaw;$cant=(int)($cantidades[$i]??0);
            if($pid<=0||$cant<=0) continue;
            $s=$db->prepare("SELECT id,nombre,precio,stock,estado FROM productos WHERE id=? FOR UPDATE");$s->execute([$pid]);$p=$s->fetch();
            if(!$p||(int)$p['estado']!==1) throw new Exception('Uno de los productos ya no está disponible.');
            if((int)$p['stock']<$cant) throw new Exception('Stock insuficiente para '.$p['nombre'].'. Disponible: '.$p['stock']);
            $sub=(float)$p['precio']*$cant;$total+=$sub;$items[]=[$pid,$cant,(float)$p['precio'],$sub];
        }
        if(!$items) throw new Exception('Debes seleccionar al menos un producto con cantidad mayor a 0.');
        $usuarioId=(int)$db->query("SELECT id FROM usuarios WHERE estado=1 ORDER BY id LIMIT 1")->fetchColumn();
        if($usuarioId<=0) throw new Exception('No existe un usuario activo para registrar la venta.');
        $s=$db->prepare("INSERT INTO ventas(cliente_id,usuario_id,fecha,total,metodo_pago,observacion) VALUES(?,?,NOW(),?,?,?)");
        $s->execute([$clienteId>0?$clienteId:null,$usuarioId,$total,$metodo,trim($_POST['observacion']??'')?:null]);
        $ventaId=(int)$db->lastInsertId();
        $sd=$db->prepare("INSERT INTO detalle_venta(venta_id,producto_id,cantidad,precio_unitario,subtotal) VALUES(?,?,?,?,?)");
        $ss=$db->prepare("UPDATE productos SET stock=stock-? WHERE id=?");
        foreach($items as $it){$sd->execute([$ventaId,$it[0],$it[1],$it[2],$it[3]]);$ss->execute([$it[1],$it[0]]);}
        $db->commit();$mensaje='Venta #'.$ventaId.' registrada correctamente. Total: S/ '.number_format($total,2);
    }catch(Throwable $e){if($db->inTransaction())$db->rollBack();$error=$e->getMessage();}
}

$clientes=$db->query("SELECT id,CONCAT(nombres,' ',COALESCE(apellidos,'')) nombre FROM clientes ORDER BY nombres")->fetchAll();
$productos=$db->query("SELECT id,nombre,marca,precio,stock FROM productos WHERE estado=1 AND stock>0 ORDER BY nombre")->fetchAll();
$ventas=$db->query("SELECT v.*,CONCAT(COALESCE(c.nombres,'Cliente'),' ',COALESCE(c.apellidos,'')) cliente,u.nombre vendedor FROM ventas v LEFT JOIN clientes c ON c.id=v.cliente_id LEFT JOIN usuarios u ON u.id=v.usuario_id ORDER BY v.id DESC")->fetchAll();

$detalle=null;
if(isset($_GET['ver'])){
    $id=(int)$_GET['ver'];
    $s=$db->prepare("SELECT v.*,CONCAT(COALESCE(c.nombres,'Cliente'),' ',COALESCE(c.apellidos,'')) cliente,u.nombre vendedor FROM ventas v LEFT JOIN clientes c ON c.id=v.cliente_id LEFT JOIN usuarios u ON u.id=v.usuario_id WHERE v.id=?");$s->execute([$id]);$detalle=$s->fetch();
    if($detalle){$s2=$db->prepare("SELECT d.*,p.nombre producto,p.marca FROM detalle_venta d JOIN productos p ON p.id=d.producto_id WHERE d.venta_id=?");$s2->execute([$id]);$detalle['items']=$s2->fetchAll();}
}
app_top('Ventas','ventas');
?>
<?php if($mensaje):?><div class="alert alert-success"><?=htmlspecialchars($mensaje)?></div><?php endif;?>
<?php if($error):?><div class="alert alert-error"><?=htmlspecialchars($error)?></div><?php endif;?>

<section class="panel">
<div class="panel-header"><h3>Nueva venta</h3><span class="muted">El stock se descuenta automáticamente</span></div>
<div class="panel-body">
<form method="post" id="ventaForm"><input type="hidden" name="accion" value="vender">
<div class="form-grid">
<div><label>Cliente</label><select name="cliente_id"><option value="0">Cliente general</option><?php foreach($clientes as $c):?><option value="<?=$c['id']?>"><?=htmlspecialchars(trim($c['nombre']))?></option><?php endforeach;?></select></div>
<div><label>Método de pago</label><select name="metodo_pago"><option value="efectivo">Efectivo</option><option value="yape">Yape</option><option value="plin">Plin</option><option value="tarjeta">Tarjeta</option><option value="transferencia">Transferencia</option></select></div>
<div class="full"><label>Productos</label><div id="filas"></div><button type="button" class="btn btn-secondary" onclick="agregarFila()">➕ Agregar producto</button></div>
<div class="full"><label>Observación</label><textarea name="observacion" placeholder="Opcional"></textarea></div>
<div class="full total-box">Total estimado: <span id="totalVista" style="margin-left:8px">S/ 0.00</span></div>
<div class="full"><button class="btn btn-primary" type="submit">✅ Registrar venta</button></div>
</div></form>
</div>
</section>

<?php if($detalle):?>
<section class="panel"><div class="panel-header"><h3>Detalle de venta #<?=$detalle['id']?></h3><a class="btn btn-secondary" href="ventas.php">Cerrar</a></div><div class="panel-body">
<p><strong>Cliente:</strong> <?=htmlspecialchars(trim($detalle['cliente']))?> &nbsp; <strong>Pago:</strong> <?=htmlspecialchars(ucfirst($detalle['metodo_pago']))?> &nbsp; <strong>Total:</strong> S/ <?=number_format((float)$detalle['total'],2)?></p>
</div><div class="table-wrap"><table><thead><tr><th>Producto</th><th>Cantidad</th><th>Precio</th><th>Subtotal</th></tr></thead><tbody>
<?php foreach($detalle['items'] as $i):?><tr><td><?=htmlspecialchars($i['producto'].' - '.$i['marca'])?></td><td><?=$i['cantidad']?></td><td>S/ <?=number_format((float)$i['precio_unitario'],2)?></td><td class="money">S/ <?=number_format((float)$i['subtotal'],2)?></td></tr><?php endforeach;?>
</tbody></table></div></section>
<?php endif;?>

<section class="panel"><div class="panel-header"><h3>Historial de ventas</h3><span class="muted"><?=count($ventas)?> ventas</span></div><div class="table-wrap"><table>
<thead><tr><th>ID</th><th>Fecha</th><th>Cliente</th><th>Vendedor</th><th>Pago</th><th>Total</th><th></th></tr></thead><tbody>
<?php foreach($ventas as $v):?><tr><td>#<?=$v['id']?></td><td><?=date('d/m/Y H:i',strtotime($v['fecha']))?></td><td><?=htmlspecialchars(trim($v['cliente']))?></td><td><?=htmlspecialchars($v['vendedor']??'')?></td><td><span class="badge badge-blue"><?=htmlspecialchars(ucfirst($v['metodo_pago']))?></span></td><td class="money">S/ <?=number_format((float)$v['total'],2)?></td><td><a class="btn btn-secondary" href="?ver=<?=$v['id']?>">👁️ Ver</a></td></tr><?php endforeach;?>
</tbody></table></div></section>

<script>
const productos = <?= json_encode($productos, JSON_UNESCAPED_UNICODE) ?>;
function opciones(){
  return '<option value="">Seleccione producto</option>'+productos.map(p=>'<option value="'+p.id+'" data-precio="'+p.precio+'">'+escapeHtml(p.nombre)+' - '+escapeHtml(p.marca)+' | Stock: '+p.stock+' | S/ '+Number(p.precio).toFixed(2)+'</option>').join('');
}
function escapeHtml(s){return String(s).replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]));}
function agregarFila(){
 const div=document.createElement('div'); div.className='sale-row';
 div.innerHTML='<div><label>Producto</label><select name="producto_id[]" onchange="recalcular()">'+opciones()+'</select></div>'+
 '<div><label>Cantidad</label><input type="number" name="cantidad[]" min="1" value="1" oninput="recalcular()"></div>'+
 '<div class="subtotal">S/ 0.00</div>'+
 '<button type="button" class="btn btn-danger" onclick="this.parentElement.remove();recalcular()">✕</button>';
 document.getElementById('filas').appendChild(div); recalcular();
}
function recalcular(){
 let total=0;
 document.querySelectorAll('.sale-row').forEach(f=>{
   const sel=f.querySelector('select'); const cant=Number(f.querySelector('input').value||0);
   const opt=sel.options[sel.selectedIndex]; const precio=Number(opt?.dataset?.precio||0); const sub=precio*cant; total+=sub;
   f.querySelector('.subtotal').textContent='S/ '+sub.toFixed(2);
 });
 document.getElementById('totalVista').textContent='S/ '+total.toFixed(2);
}
agregarFila();
</script>
<?php app_bottom(); ?>