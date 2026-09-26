<?php
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/config/auth.php';
require_role(['admin']);

try {
    $db = (new Database())->getConnection();

    $nombreArchivo = 'backup_venta_electrodomesticos_' . date('Y-m-d_H-i-s') . '.sql';

    header('Content-Type: application/sql; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $nombreArchivo . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    echo "-- Backup de venta_electrodomesticos\n";
    echo "-- Generado: " . date('Y-m-d H:i:s') . "\n\n";
    echo "SET FOREIGN_KEY_CHECKS=0;\n\n";

    $tablas = $db->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);

    foreach ($tablas as $tabla) {
        $create = $db->query("SHOW CREATE TABLE `$tabla`")->fetch(PDO::FETCH_NUM);

        echo "DROP TABLE IF EXISTS `$tabla`;\n";
        echo $create[1] . ";\n\n";

        $filas = $db->query("SELECT * FROM `$tabla`")->fetchAll(PDO::FETCH_ASSOC);

        foreach ($filas as $fila) {
            $columnas = array_map(fn($c) => "`$c`", array_keys($fila));
            $valores = [];

            foreach ($fila as $valor) {
                if ($valor === null) {
                    $valores[] = "NULL";
                } else {
                    $valores[] = $db->quote((string)$valor);
                }
            }

            echo "INSERT INTO `$tabla` (" . implode(",", $columnas) . ") VALUES (" . implode(",", $valores) . ");\n";
        }

        echo "\n";
    }

    echo "SET FOREIGN_KEY_CHECKS=1;\n";
    exit;

} catch (Throwable $e) {
    http_response_code(500);
    echo "No se pudo generar el backup: " . $e->getMessage();
}
?>