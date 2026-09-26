<?php
require_once "../config/database.php";
require_once "../config/helpers.php";
$db=(new Database())->getConnection();
$method=$_SERVER["REQUEST_METHOD"];

if($method==="GET"){
    if(isset($_GET["id"])){
        $s=$db->prepare("SELECT * FROM clientes WHERE id=?");
        $s->execute([(int)$_GET["id"]]); $r=$s->fetch();
        if(!$r) responder(false,"Cliente no encontrado",null,404);
        responder(true,"Cliente encontrado",$r);
    }
    responder(true,"Lista de clientes",$db->query("SELECT * FROM clientes ORDER BY id DESC")->fetchAll());
}
if($method==="POST"){
    $d=jsonInput(); requerido($d,["nombres"]);
    $s=$db->prepare("INSERT INTO clientes(nombres,apellidos,dni,telefono,email,direccion) VALUES(?,?,?,?,?,?)");
    $s->execute([$d["nombres"],$d["apellidos"]??null,$d["dni"]??null,$d["telefono"]??null,$d["email"]??null,$d["direccion"]??null]);
    responder(true,"Cliente registrado",["id"=>(int)$db->lastInsertId()],201);
}
if($method==="PUT"){
    $d=jsonInput(); requerido($d,["id","nombres"]);
    $s=$db->prepare("UPDATE clientes SET nombres=?,apellidos=?,dni=?,telefono=?,email=?,direccion=? WHERE id=?");
    $s->execute([$d["nombres"],$d["apellidos"]??null,$d["dni"]??null,$d["telefono"]??null,$d["email"]??null,$d["direccion"]??null,(int)$d["id"]]);
    responder(true,"Cliente actualizado");
}
if($method==="DELETE"){
    $d=jsonInput(); requerido($d,["id"]);
    try{
        $s=$db->prepare("DELETE FROM clientes WHERE id=?"); $s->execute([(int)$d["id"]]);
        responder(true,"Cliente eliminado");
    }catch(PDOException $e){
        responder(false,"No se puede eliminar: el cliente tiene ventas registradas",null,409);
    }
}
responder(false,"Método no permitido",null,405);
?>