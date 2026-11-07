<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";

if (!esta_logueado()) {
    responder(false,"Debes iniciar sesión",null,401);
}

if (!in_array(rol_actual(), ['admin','vendedor'], true)) {
    responder(false,"No tienes permiso para esta API",null,403);
}

$db=(new Database())->getConnection();

$db->exec("
    CREATE TABLE IF NOT EXISTS proveedores (
        id INT AUTO_INCREMENT PRIMARY KEY,
        razon_social VARCHAR(150) NOT NULL,
        ruc VARCHAR(11) NOT NULL UNIQUE,
        contacto VARCHAR(120) NULL,
        telefono VARCHAR(20) NULL,
        email VARCHAR(120) NULL,
        direccion VARCHAR(220) NULL,
        estado TINYINT(1) NOT NULL DEFAULT 1,
        creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_proveedor_nombre (razon_social),
        INDEX idx_proveedor_estado (estado)
    ) ENGINE=InnoDB
");

$method=$_SERVER["REQUEST_METHOD"];

if ($method!=="GET" && !es_admin()) {
    responder(false,"Solo el administrador puede realizar esta operación",null,403);
}

if($method==="GET"){
    if(isset($_GET["id"])){
        $s=$db->prepare("SELECT * FROM proveedores WHERE id=?");
        $s->execute([(int)$_GET["id"]]);
        $r=$s->fetch();

        if(!$r) responder(false,"Proveedor no encontrado",null,404);

        responder(true,"Proveedor encontrado",$r);
    }

    $q=trim($_GET["q"]??"");

    if($q!==""){
        $like="%$q%";
        $s=$db->prepare("
            SELECT *
            FROM proveedores
            WHERE razon_social LIKE ?
               OR ruc LIKE ?
               OR contacto LIKE ?
               OR telefono LIKE ?
            ORDER BY estado DESC, razon_social
        ");
        $s->execute([$like,$like,$like,$like]);
        responder(true,"Resultados de búsqueda",$s->fetchAll());
    }

    responder(
        true,
        "Lista de proveedores",
        $db->query("SELECT * FROM proveedores ORDER BY estado DESC, razon_social")->fetchAll()
    );
}

if($method==="POST"){
    $d=jsonInput();
    requerido($d,["razon_social","ruc"]);

    if(!preg_match('/^\d{11}$/',(string)$d["ruc"])){
        responder(false,"El RUC debe tener 11 números",null,422);
    }

    if(!empty($d["email"]) && !filter_var($d["email"],FILTER_VALIDATE_EMAIL)){
        responder(false,"Correo electrónico inválido",null,422);
    }

    try{
        $s=$db->prepare("
            INSERT INTO proveedores(razon_social,ruc,contacto,telefono,email,direccion,estado)
            VALUES(?,?,?,?,?,?,1)
        ");
        $s->execute([
            trim($d["razon_social"]),
            trim($d["ruc"]),
            !empty($d["contacto"]) ? trim($d["contacto"]) : null,
            !empty($d["telefono"]) ? trim($d["telefono"]) : null,
            !empty($d["email"]) ? trim($d["email"]) : null,
            !empty($d["direccion"]) ? trim($d["direccion"]) : null
        ]);

        responder(true,"Proveedor registrado",["id"=>(int)$db->lastInsertId()],201);
    }catch(PDOException $e){
        if(str_contains($e->getMessage(),"Duplicate entry")){
            responder(false,"El RUC ya está registrado",null,409);
        }
        throw $e;
    }
}

if($method==="PUT"){
    $d=jsonInput();
    requerido($d,["id","razon_social","ruc"]);

    if(!preg_match('/^\d{11}$/',(string)$d["ruc"])){
        responder(false,"El RUC debe tener 11 números",null,422);
    }

    if(!empty($d["email"]) && !filter_var($d["email"],FILTER_VALIDATE_EMAIL)){
        responder(false,"Correo electrónico inválido",null,422);
    }

    try{
        $s=$db->prepare("
            UPDATE proveedores
            SET razon_social=?, ruc=?, contacto=?, telefono=?, email=?, direccion=?, estado=?
            WHERE id=?
        ");
        $s->execute([
            trim($d["razon_social"]),
            trim($d["ruc"]),
            !empty($d["contacto"]) ? trim($d["contacto"]) : null,
            !empty($d["telefono"]) ? trim($d["telefono"]) : null,
            !empty($d["email"]) ? trim($d["email"]) : null,
            !empty($d["direccion"]) ? trim($d["direccion"]) : null,
            isset($d["estado"]) ? (int)$d["estado"] : 1,
            (int)$d["id"]
        ]);

        responder(true,"Proveedor actualizado");
    }catch(PDOException $e){
        if(str_contains($e->getMessage(),"Duplicate entry")){
            responder(false,"El RUC ya está registrado",null,409);
        }
        throw $e;
    }
}

if($method==="DELETE"){
    $d=jsonInput();
    requerido($d,["id"]);

    $s=$db->prepare("UPDATE proveedores SET estado=0 WHERE id=?");
    $s->execute([(int)$d["id"]]);

    responder(true,"Proveedor desactivado");
}

responder(false,"Método no permitido",null,405);
?>