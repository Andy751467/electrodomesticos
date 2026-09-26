<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
if($_SERVER["REQUEST_METHOD"]!=="POST") responder(false,"Método no permitido",null,405);
$d=jsonInput(); requerido($d,["usuario","password"]);
$db=(new Database())->getConnection();
$s=$db->prepare("SELECT id,nombre,usuario,password,rol FROM usuarios WHERE usuario=? AND estado=1 LIMIT 1");
$s->execute([$d["usuario"]]); $u=$s->fetch();
if(!$u || !password_verify($d["password"],$u["password"])) responder(false,"Usuario o contraseña incorrectos",null,401);
unset($u["password"]);
responder(true,"Inicio de sesión correcto",$u);
?>