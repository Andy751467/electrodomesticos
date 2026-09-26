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
        $s=$db->prepare("SELECT * FROM categorias WHERE id=?");
        $s->execute([(int)$_GET["id"]]);
        $r=$s->fetch();
        if(!$r) responder(false,"Categoría no encontrada",null,404);
        responder(true,"Categoría encontrada",$r);
    }
    responder(true,"Lista de categorías",$db->query("SELECT * FROM categorias ORDER BY nombre")->fetchAll());
}

if($method==="POST"){
    $d=jsonInput(); requerido($d,["nombre"]);
    $s=$db->prepare("INSERT INTO categorias(nombre,descripcion) VALUES(?,?)");
    $s->execute([$d["nombre"],$d["descripcion"]??null]);
    responder(true,"Categoría registrada",["id"=>(int)$db->lastInsertId()],201);
}

if($method==="PUT"){
    $d=jsonInput(); requerido($d,["id","nombre"]);
    $s=$db->prepare("UPDATE categorias SET nombre=?,descripcion=? WHERE id=?");
    $s->execute([$d["nombre"],$d["descripcion"]??null,(int)$d["id"]]);
    responder(true,"Categoría actualizada");
}

if($method==="DELETE"){
    $d=jsonInput(); requerido($d,["id"]);
    try{
        $s=$db->prepare("DELETE FROM categorias WHERE id=?");
        $s->execute([(int)$d["id"]]);
        responder(true,"Categoría eliminada");
    }catch(PDOException $e){
        responder(false,"No se puede eliminar: la categoría está en uso",null,409);
    }
}
responder(false,"Método no permitido",null,405);
?>