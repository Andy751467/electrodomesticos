<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";
if (!esta_logueado()) responder(false,"Debes iniciar sesión",null,401);
$db=(new Database())->getConnection();

$columnas=$db->query("SHOW COLUMNS FROM productos")->fetchAll(PDO::FETCH_COLUMN);
if(!in_array("codigo_sku",$columnas,true)) $db->exec("ALTER TABLE productos ADD codigo_sku VARCHAR(50) NULL AFTER categoria_id");
if(!in_array("stock_minimo",$columnas,true)) $db->exec("ALTER TABLE productos ADD stock_minimo INT NOT NULL DEFAULT 5 AFTER stock");
$db->exec("UPDATE productos SET codigo_sku=CONCAT('PROD-',LPAD(id,4,'0')) WHERE codigo_sku IS NULL OR TRIM(codigo_sku)=''");
$idx=$db->query("SHOW INDEX FROM productos WHERE Key_name='idx_producto_sku'")->fetchAll();
if(!$idx) $db->exec("ALTER TABLE productos ADD UNIQUE INDEX idx_producto_sku (codigo_sku)");

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
        $s=$db->prepare("SELECT p.*,c.nombre categoria FROM productos p LEFT JOIN categorias c ON c.id=p.categoria_id WHERE p.codigo_sku LIKE ? OR p.nombre LIKE ? OR p.marca LIKE ? OR c.nombre LIKE ? ORDER BY p.id DESC");
        $s->execute([$like,$like,$like,$like]);
        responder(true,"Resultados de búsqueda",$s->fetchAll());
    }
    responder(true,"Lista de productos",$db->query("SELECT p.*,c.nombre categoria FROM productos p LEFT JOIN categorias c ON c.id=p.categoria_id ORDER BY p.id DESC")->fetchAll());
}

if($method==="POST"){
    $d=jsonInput(); requerido($d,["categoria_id","codigo_sku","nombre","marca","precio","stock"]);
    if((float)$d["precio"]<0 || (int)$d["stock"]<0 || (int)($d["stock_minimo"]??5)<0) responder(false,"Precio, stock y stock mínimo no pueden ser negativos",null,422);
    $s=$db->prepare("INSERT INTO productos(categoria_id,codigo_sku,nombre,marca,modelo,precio,stock,stock_minimo,descripcion,imagen,estado) VALUES(?,?,?,?,?,?,?,?,?,?,1)");
    $s->execute([(int)$d["categoria_id"],strtoupper(trim($d["codigo_sku"])),$d["nombre"],$d["marca"],$d["modelo"]??null,(float)$d["precio"],(int)$d["stock"],(int)($d["stock_minimo"]??5),$d["descripcion"]??null,$d["imagen"]??null]);
    responder(true,"Producto registrado",["id"=>(int)$db->lastInsertId()],201);
}

if($method==="PUT"){
    $d=jsonInput(); requerido($d,["id","categoria_id","codigo_sku","nombre","marca","precio","stock"]);
    $s=$db->prepare("UPDATE productos SET categoria_id=?,codigo_sku=?,nombre=?,marca=?,modelo=?,precio=?,stock=?,stock_minimo=?,descripcion=?,imagen=?,estado=? WHERE id=?");
    $s->execute([(int)$d["categoria_id"],strtoupper(trim($d["codigo_sku"])),$d["nombre"],$d["marca"],$d["modelo"]??null,(float)$d["precio"],(int)$d["stock"],(int)($d["stock_minimo"]??5),$d["descripcion"]??null,$d["imagen"]??null,isset($d["estado"])?(int)$d["estado"]:1,(int)$d["id"]]);
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