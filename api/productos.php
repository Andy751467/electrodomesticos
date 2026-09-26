<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";
if (!esta_logueado()) responder(false,"Debes iniciar sesión",null,401);
$db=(new Database())->getConnection();
$method=$_SERVER["REQUEST_METHOD"];
if ($method!=="GET" && !es_admin()) responder(false,"Solo el administrador puede realizar esta operación",null,403);

if($method==="GET"){
    if(isset($_GET["id"])){
        $s=$db->prepare("SELECT p.*,c.nombre categoria FROM productos p LEFT JOIN categorias c ON c.id=p.categoria_id WHERE p.id=?");
        $s->execute([(int)$_GET["id"]]); $r=$s->fetch();
        if(!$r) responder(false,"Producto no encontrado",null,404);
        responder(true,"Producto encontrado",$r);
    }
    $q=trim($_GET["q"]??"");
    if($q!==""){
        $like="%$q%";
        $s=$db->prepare("SELECT p.*,c.nombre categoria FROM productos p LEFT JOIN categorias c ON c.id=p.categoria_id WHERE p.nombre LIKE ? OR p.marca LIKE ? OR c.nombre LIKE ? ORDER BY p.id DESC");
        $s->execute([$like,$like,$like]);
        responder(true,"Resultados de búsqueda",$s->fetchAll());
    }
    responder(true,"Lista de productos",$db->query("SELECT p.*,c.nombre categoria FROM productos p LEFT JOIN categorias c ON c.id=p.categoria_id ORDER BY p.id DESC")->fetchAll());
}

if($method==="POST"){
    $d=jsonInput(); requerido($d,["categoria_id","nombre","marca","precio","stock"]);
    if((float)$d["precio"]<0 || (int)$d["stock"]<0) responder(false,"Precio y stock no pueden ser negativos",null,422);
    $s=$db->prepare("INSERT INTO productos(categoria_id,nombre,marca,modelo,precio,stock,descripcion,imagen,estado) VALUES(?,?,?,?,?,?,?,?,1)");
    $s->execute([(int)$d["categoria_id"],$d["nombre"],$d["marca"],$d["modelo"]??null,(float)$d["precio"],(int)$d["stock"],$d["descripcion"]??null,$d["imagen"]??null]);
    responder(true,"Producto registrado",["id"=>(int)$db->lastInsertId()],201);
}

if($method==="PUT"){
    $d=jsonInput(); requerido($d,["id","categoria_id","nombre","marca","precio","stock"]);
    $s=$db->prepare("UPDATE productos SET categoria_id=?,nombre=?,marca=?,modelo=?,precio=?,stock=?,descripcion=?,imagen=?,estado=? WHERE id=?");
    $s->execute([(int)$d["categoria_id"],$d["nombre"],$d["marca"],$d["modelo"]??null,(float)$d["precio"],(int)$d["stock"],$d["descripcion"]??null,$d["imagen"]??null,isset($d["estado"])?(int)$d["estado"]:1,(int)$d["id"]]);
    responder(true,"Producto actualizado");
}

if($method==="DELETE"){
    $d=jsonInput(); requerido($d,["id"]);
    try{
        $s=$db->prepare("DELETE FROM productos WHERE id=?"); $s->execute([(int)$d["id"]]);
        responder(true,"Producto eliminado");
    }catch(PDOException $e){
        $s=$db->prepare("UPDATE productos SET estado=0 WHERE id=?"); $s->execute([(int)$d["id"]]);
        responder(true,"Producto desactivado porque ya tiene movimientos");
    }
}
responder(false,"Método no permitido",null,405);
?>