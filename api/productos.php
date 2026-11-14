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


// Validación centralizada: el servidor nunca confía en los valores de Flutter.
function validarProducto(PDO $db, array $d, bool $nuevo = false): array {
    requerido($d,["categoria_id","codigo_sku","nombre","marca","precio","stock","stock_minimo"]);
    $categoria = filter_var($d["categoria_id"], FILTER_VALIDATE_INT);
    if ($categoria === false || $categoria < 1) {
        responder(false,"Selecciona una categoría válida",null,422);
    }

    $cat = $db->prepare("SELECT COUNT(*) FROM categorias WHERE id=?");
    $cat->execute([$categoria]);
    if (!(int)$cat->fetchColumn()) {
        responder(false,"La categoría seleccionada no existe",null,422);
    }

    $sku = strtoupper(trim((string)$d["codigo_sku"]));
    if (!preg_match('/^[A-Z0-9_-]{2,50}$/', $sku)) {
        responder(false,"El SKU debe tener entre 2 y 50 letras, números o guiones",null,422);
    }
    $nombre = trim((string)$d["nombre"]);
    $marca = trim((string)$d["marca"]);
    $modelo = trim((string)($d["modelo"] ?? ""));
    $descripcion = trim((string)($d["descripcion"] ?? ""));
    $imagen = trim((string)($d["imagen"] ?? ""));

    $largo = static fn(string $v): int => function_exists('mb_strlen')
        ? mb_strlen($v,'UTF-8') : strlen($v);
    if ($nombre === "" || $largo($nombre) > 120 ||
        $marca === "" || $largo($marca) > 80 ||
        $largo($modelo) > 80 || $largo($imagen) > 255) {
        responder(false,"Nombre, marca, modelo o imagen tienen longitud inválida",null,422);
    }

    $precioTexto = str_replace(",",".",(string)$d["precio"]);
    if (!preg_match('/^\d+(\.\d{1,2})?$/',$precioTexto) ||
        (float)$precioTexto > 99999999.99) {
        responder(false,"El precio debe ser positivo y tener máximo dos decimales",null,422);
    }

    foreach (["stock", "stock_minimo"] as $campo) {
        $n = filter_var($d[$campo], FILTER_VALIDATE_INT);
        if ($n === false || $n < 0 || $n > 100000000) {
            responder(false, "El campo '$campo' debe ser un entero no negativo",null,422);
        }
    }
    $estado = isset($d["estado"]) ? filter_var($d["estado"], FILTER_VALIDATE_INT) : 1;
    if ($estado !== 0 && $estado !== 1) {
        responder(false,"Estado de producto inválido",null,422);
    }

    return [
        "categoria_id" => (int)$categoria,
        "codigo_sku" => $sku,
        "nombre" => $nombre,
        "marca" => $marca,
        "modelo" => $modelo !== "" ? $modelo : null,
        "precio" => (float)$precioTexto,
        "stock" => (int)$d["stock"],
        "stock_minimo" => (int)$d["stock_minimo"],
        "descripcion" => $descripcion !== "" ? $descripcion : null,
        "imagen" => $imagen !== "" ? $imagen : null,
        "estado" => (int)$estado
    ];
}

if($method==="POST"){
    $d = validarProducto($db, jsonInput(), true);
    try {
        $s=$db->prepare("INSERT INTO productos(categoria_id,codigo_sku,nombre,marca,modelo,precio,stock,stock_minimo,descripcion,imagen,estado) VALUES(?,?,?,?,?,?,?,?,?,?,?)");
        $s->execute([
            $d["categoria_id"],$d["codigo_sku"],$d["nombre"],$d["marca"],
            $d["modelo"],$d["precio"],$d["stock"],$d["stock_minimo"],
            $d["descripcion"],$d["imagen"],$d["estado"]
        ]);
        responder(true,"Producto registrado correctamente",["id"=>(int)$db->lastInsertId()],201);
    } catch(PDOException $e) {
        if($e->getCode()==="23000") {
            responder(false,"El SKU ya existe o la categoría es inválida",null,409);
        }
        responder(false,"No se pudo registrar el producto",null,500);
    }
}

if($method==="PUT"){
    $d = jsonInput();
    requerido($d,["id"]);
    $id = filter_var($d["id"],FILTER_VALIDATE_INT);
    if ($id===false || $id<1) responder(false,"ID inválido",null,422);
    $actual = $db->prepare("SELECT id FROM productos WHERE id=?");
    $actual->execute([$id]);
    if (!$actual->fetch()) responder(false,"Producto no encontrado",null,404);
    $d = validarProducto($db,$d);
    try {
        $s=$db->prepare("UPDATE productos SET categoria_id=?,codigo_sku=?,nombre=?,marca=?,modelo=?,precio=?,stock=?,stock_minimo=?,descripcion=?,imagen=?,estado=? WHERE id=?");
        $s->execute([
            $d["categoria_id"],$d["codigo_sku"],$d["nombre"],$d["marca"],
            $d["modelo"],$d["precio"],$d["stock"],$d["stock_minimo"],
            $d["descripcion"],$d["imagen"],$d["estado"],(int)$id
        ]);
        responder(true,"Producto actualizado correctamente");
    } catch(PDOException $e) {
        if($e->getCode()==="23000") {
            responder(false,"El SKU ya existe o la categoría es inválida",null,409);
        }
        responder(false,"No se pudo actualizar el producto",null,500);
    }
}

if($method==="DELETE"){
    $d=jsonInput(); requerido($d,["id"]);
    $id=filter_var($d["id"],FILTER_VALIDATE_INT);
    if($id===false || $id<1) responder(false,"ID inválido",null,422);
    $check=$db->prepare("SELECT id FROM productos WHERE id=?");
    $check->execute([$id]);
    if(!$check->fetch()) responder(false,"Producto no encontrado",null,404);
    try {
        $s=$db->prepare("DELETE FROM productos WHERE id=?");
        $s->execute([$id]);
        responder(true,"Producto eliminado correctamente");
    } catch(PDOException $e) {
        if($e->getCode()!=="23000") {
            responder(false,"No se pudo eliminar el producto",null,500);
        }
        $s=$db->prepare("UPDATE productos SET estado=0 WHERE id=?");
        $s->execute([$id]);
        responder(true,"Producto desactivado para conservar el historial de ventas");
    }
}
responder(false,"Método no permitido",null,405);
?>