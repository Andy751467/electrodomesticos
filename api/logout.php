<?php
require_once "../config/helpers.php";
require_once "../config/auth.php";

if($_SERVER["REQUEST_METHOD"]!=="POST"){
    responder(false,"Método no permitido",null,405);
}

$_SESSION=[];

if(ini_get("session.use_cookies")){
    $params=session_get_cookie_params();
    setcookie(
        session_name(),
        "",
        time()-42000,
        $params["path"],
        $params["domain"],
        $params["secure"],
        $params["httponly"]
    );
}

session_destroy();

responder(true,"Sesión cerrada correctamente");
?>