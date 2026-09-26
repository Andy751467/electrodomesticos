<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/includes/layout.php';
$db=(new Database())->getConnection();
$mensaje=$error='';$editar=null;

try{
    if($_SERVER['REQUEST_METHOD']==='POST'){
        $accion=$_POST['accion']??'';
        if($accion==='guardar'){
            $id=(int)($_POST['id']??0);
            $categoria=(int)($_POST['categoria_id']??0);
            $nombre=trim($_POST['nombre']??'');
            $marca=trim($_POST['marca']??'');
            $modelo=trim($_POST['modelo']??'');
            $precio=(float)($_POST['precio']??0);
            $stock=(int)($_POST['stock']??0);
            $descripcion=trim($_POST['descripcion']??'');
            if($categoria<=0||$nombre===''||$marca==='') throw new Exception('Categoría, nombre y marca son obligatorios.');
            if($precio<0||$stock<0) throw new Exception('Precio y stock no pueden ser negativos.');
            if($id>0){
                $s=$db->prepare("UPDATE productos SET categoria_id=?,nombre=?,marca=?,modelo=?,precio=?,stock=?,descripcion=?,estado=1 WHERE id=?");
                $s->execute([$categoria,$nombre,$marca,$modelo?:null,$precio,$stock,$descripcion?:null,$id]);
                $mensaje='Producto actualizado correctamente.';
            }else{
                $s=$db->prepare("INSERT INTO productos(categoria_id,nombre,marca,modelo,precio,stock,descripcion,estado) VALUES(?,?,?,?,?,?,?,1)");
                $s->execute([$categoria,$nombre,$marca,$modelo?:null,$precio,$stock,$descripcion?:null]);
                $mensaje='Producto registrado correctamente.';
            }
        }
        if($accion==='eliminar'){
            $id=(int)($_POST['id']??0);
            $s=$db->prepare("UPDATE productos SET estado=0 WHERE id=?");$s->execute([$id]);
            $mensaje='Producto desactivado correctamente.';
        }
    }
}catch(Throwable $e){$error=$e->getMessage();}

if(isset($_GET['editar'])){
    $s=$db->prepare("SELECT * FROM productos WHERE id=?");$s->execute([(int)$_GET['editar']]);$editar=$s->fetch();
}
$categorias=$db->query("SELECT id,nombre FROM categorias ORDER BY nombre")->fetchAll();
$q=trim($_GET['q']??'');
if($q!==''){
    $s=$db->prepare("SELECT p.*,c.nombre categoria FROM productos p JOIN categorias c ON c.id=p.categoria_id WHERE p.estado=1 AND (p.nombre LIKE ? OR p.marca LIKE ? OR p.modelo LIKE ?) ORDER BY p.id DESC");
    $like="%$q%";$s->execute([$like,$like,$like]);$productos=$s->fetchAll();
}else{
    $productos=$db->query("SELECT p.*,c.nombre categoria FROM productos p JOIN categorias c ON c.id=p.categoria_id WHERE p.estado=1 ORDER BY p.id DESC")->fetchAll();
}
app_top('Productos','productos');
?>
<?php if($mensaje): ?><div class="alert alert-success"><?=htmlspecialchars($mensaje)?></div><?php endif; ?>
<?php if($error): ?><div class="alert alert-error"><?=htmlspecialchars($error)?></div><?php endif; ?>

<section class="panel">
<div class="panel-header"><h3><?= $editar?'Editar producto':'Nuevo producto' ?></h3></div>
<div class="panel-body">
<form method="post">
<input type="hidden" name="accion" value="guardar"><input type="hidden" name="id" value="<?=(int)($editar['id']??0)?>">
<div class="form-grid">
<div><label>Categoría</label><select name="categoria_id" required><option value="">Seleccione</option><?php foreach($categorias as $c): ?><option value="<?=$c['id']?>" <?=((int)($editar['categoria_id']??0)===(int)$c['id'])?'selected':''?>><?=htmlspecialchars($c['nombre'])?></option><?php endforeach; ?></select></div>
<div><label>Nombre</label><input name="nombre" required value="<?=htmlspecialchars($editar['nombre']??'')?>" placeholder="Ej. Smart TV 55 pulgadas"></div>
<div><label>Marca</label><input name="marca" required value="<?=htmlspecialchars($editar['marca']??'')?>" placeholder="Ej. Samsung"></div>
<div><label>Modelo</label><input name="modelo" value="<?=htmlspecialchars($editar['modelo']??'')?>" placeholder="Ej. UHD55"></div>
<div><label>Precio (S/)</label><input type="number" step="0.01" min="0" name="precio" required value="<?=htmlspecialchars((string)($editar['precio']??''))?>"></div>
<div><label>Stock</label><input type="number" min="0" name="stock" required value="<?=htmlspecialchars((string)($editar['stock']??''))?>"></div>
<div class="full"><label>Descripción</label><textarea name="descripcion"><?=htmlspecialchars($editar['descripcion']??'')?></textarea></div>
<div class="full actions"><button class="btn btn-primary">💾 Guardar producto</button><?php if($editar): ?><a class="btn btn-secondary" href="productos.php">Cancelar</a><?php endif; ?></div>
</div>
</form>
</div>
</section>

<div class="toolbar">
<form class="search" method="get"><input name="q" value="<?=htmlspecialchars($q)?>" placeholder="Buscar por nombre, marca o modelo"><button class="btn btn-primary">🔎 Buscar</button><?php if($q!==''):?><a class="btn btn-secondary" href="productos.php">Limpiar</a><?php endif;?></form>
</div>

<section class="panel">
<div class="panel-header"><h3>Inventario de productos</h3><span class="muted"><?=count($productos)?> productos</span></div>
<div class="table-wrap"><table>
<thead><tr><th>ID</th><th>Producto</th><th>Categoría</th><th>Marca/Modelo</th><th>Precio</th><th>Stock</th><th>Acciones</th></tr></thead>
<tbody>
<?php foreach($productos as $p): ?>
<tr>
<td>#<?=$p['id']?></td><td><strong><?=htmlspecialchars($p['nombre'])?></strong><br><small class="muted"><?=htmlspecialchars($p['descripcion']??'')?></small></td>
<td><?=htmlspecialchars($p['categoria'])?></td><td><?=htmlspecialchars($p['marca'])?> <?=htmlspecialchars($p['modelo']??'')?></td>
<td class="money">S/ <?=number_format((float)$p['precio'],2)?></td>
<td><span class="badge <?=((int)$p['stock']<=5)?'badge-red':'badge-green'?>"><?=(int)$p['stock']?> und.</span></td>
<td><div class="actions"><a class="btn btn-secondary" href="?editar=<?=$p['id']?>">✏️ Editar</a><form method="post" onsubmit="return confirm('¿Desactivar este producto?')"><input type="hidden" name="accion" value="eliminar"><input type="hidden" name="id" value="<?=$p['id']?>"><button class="btn btn-danger">🗑️ Desactivar</button></form></div></td>
</tr>
<?php endforeach; ?>
<?php if(!$productos): ?><tr><td colspan="7" class="empty">No se encontraron productos.</td></tr><?php endif; ?>
</tbody></table></div>
</section>
<?php app_bottom(); ?>