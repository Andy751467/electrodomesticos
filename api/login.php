<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
require_once "../config/auth.php";

if($_SERVER["REQUEST_METHOD"]!=="POST"){
    responder(false,"Método no permitido",null,405);
}

$d=jsonInput();
requerido($d,["usuario","password"]);

$db=(new Database())->getConnection();

$s=$db->prepare("
    SELECT id,nombre,usuario,password,rol,estado
    FROM usuarios
    WHERE usuario=? AND estado=1
    LIMIT 1
");
$s->execute([$d["usuario"]]);
$u=$s->fetch();

if(!$u || !password_verify($d["password"],$u["password"])){
    responder(false,"Usuario o contraseña incorrectos",null,401);
}

session_regenerate_id(true);

$_SESSION["usuario"]=[
    "id"=>(int)$u["id"],
    "nombre"=>$u["nombre"],
    "usuario"=>$u["usuario"],
    "rol"=>$u["rol"]
];

unset($u["password"]);
unset($u["estado"]);

responder(true,"Inicio de sesión correcto",$u);
?>