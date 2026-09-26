<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_role(['admin','vendedor']);
require_once __DIR__ . '/includes/layout.php';
$db=(new Database())->getConnection();
$mensaje=$error='';$editar=null;
try{
if($_SERVER['REQUEST_METHOD']==='POST'){
    $accion=$_POST['accion']??'';
    if($accion==='guardar'){
        $id=(int)($_POST['id']??0);$nombres=trim($_POST['nombres']??'');$apellidos=trim($_POST['apellidos']??'');
        $dni=trim($_POST['dni']??'');$telefono=trim($_POST['telefono']??'');$email=trim($_POST['email']??'');$direccion=trim($_POST['direccion']??'');
        if($nombres==='') throw new Exception('El nombre del cliente es obligatorio.');
        if($id>0){
            $s=$db->prepare("UPDATE clientes SET nombres=?,apellidos=?,dni=?,telefono=?,email=?,direccion=? WHERE id=?");
            $s->execute([$nombres,$apellidos?:null,$dni?:null,$telefono?:null,$email?:null,$direccion?:null,$id]);$mensaje='Cliente actualizado correctamente.';
        }else{
            $s=$db->prepare("INSERT INTO clientes(nombres,apellidos,dni,telefono,email,direccion) VALUES(?,?,?,?,?,?)");
            $s->execute([$nombres,$apellidos?:null,$dni?:null,$telefono?:null,$email?:null,$direccion?:null]);$mensaje='Cliente registrado correctamente.';
        }
    }
    if($accion==='eliminar'){
        $id=(int)($_POST['id']??0);$s=$db->prepare("DELETE FROM clientes WHERE id=?");$s->execute([$id]);$mensaje='Cliente eliminado correctamente.';
    }
}}catch(Throwable $e){
    $error=str_contains($e->getMessage(),'Integrity constraint')?'No se puede eliminar o repetir el DNI de este cliente porque tiene información relacionada.':$e->getMessage();
}
if(isset($_GET['editar'])){$s=$db->prepare("SELECT * FROM clientes WHERE id=?");$s->execute([(int)$_GET['editar']]);$editar=$s->fetch();}
$q=trim($_GET['q']??'');
if($q!==''){$like="%$q%";$s=$db->prepare("SELECT * FROM clientes WHERE nombres LIKE ? OR apellidos LIKE ? OR dni LIKE ? ORDER BY id DESC");$s->execute([$like,$like,$like]);$clientes=$s->fetchAll();}
else{$clientes=$db->query("SELECT * FROM clientes ORDER BY id DESC")->fetchAll();}
app_top('Clientes','clientes');
?>
<?php if($mensaje):?><div class="alert alert-success"><?=htmlspecialchars($mensaje)?></div><?php endif;?>
<?php if($error):?><div class="alert alert-error"><?=htmlspecialchars($error)?></div><?php endif;?>
<section class="panel"><div class="panel-header"><h3><?=$editar?'Editar cliente':'Nuevo cliente'?></h3></div><div class="panel-body">
<form method="post"><input type="hidden" name="accion" value="guardar"><input type="hidden" name="id" value="<?=(int)($editar['id']??0)?>">
<div class="form-grid">
<div><label>Nombres</label><input name="nombres" required value="<?=htmlspecialchars($editar['nombres']??'')?>"></div>
<div><label>Apellidos</label><input name="apellidos" value="<?=htmlspecialchars($editar['apellidos']??'')?>"></div>
<div><label>DNI</label><input name="dni" maxlength="15" value="<?=htmlspecialchars($editar['dni']??'')?>"></div>
<div><label>Teléfono</label><input name="telefono" value="<?=htmlspecialchars($editar['telefono']??'')?>"></div>
<div><label>Correo</label><input type="email" name="email" value="<?=htmlspecialchars($editar['email']??'')?>"></div>
<div><label>Dirección</label><input name="direccion" value="<?=htmlspecialchars($editar['direccion']??'')?>"></div>
<div class="full actions"><button class="btn btn-primary">💾 Guardar cliente</button><?php if($editar):?><a class="btn btn-secondary" href="clientes.php">Cancelar</a><?php endif;?></div>
</div></form></div></section>
<div class="toolbar"><form class="search"><input name="q" value="<?=htmlspecialchars($q)?>" placeholder="Buscar nombre, apellido o DNI"><button class="btn btn-primary">🔎 Buscar</button><?php if($q!==''):?><a class="btn btn-secondary" href="clientes.php">Limpiar</a><?php endif;?></form></div>
<section class="panel"><div class="panel-header"><h3>Lista de clientes</h3><span class="muted"><?=count($clientes)?> registros</span></div><div class="table-wrap"><table>
<thead><tr><th>ID</th><th>Cliente</th><th>DNI</th><th>Teléfono</th><th>Correo</th><th>Dirección</th><th>Acciones</th></tr></thead><tbody>
<?php foreach($clientes as $c):?><tr><td>#<?=$c['id']?></td><td><strong><?=htmlspecialchars(trim($c['nombres'].' '.($c['apellidos']??'')))?></strong></td><td><?=htmlspecialchars($c['dni']??'-')?></td><td><?=htmlspecialchars($c['telefono']??'-')?></td><td><?=htmlspecialchars($c['email']??'-')?></td><td><?=htmlspecialchars($c['direccion']??'-')?></td><td><div class="actions"><a class="btn btn-secondary" href="?editar=<?=$c['id']?>">✏️ Editar</a><form method="post" onsubmit="return confirm('¿Eliminar este cliente?')"><input type="hidden" name="accion" value="eliminar"><input type="hidden" name="id" value="<?=$c['id']?>"><button class="btn btn-danger">🗑️ Eliminar</button></form></div></td></tr><?php endforeach;?>
<?php if(!$clientes):?><tr><td colspan="7" class="empty">No hay clientes registrados.</td></tr><?php endif;?>
</tbody></table></div></section>
<?php app_bottom(); ?>