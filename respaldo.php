<?php
require_once __DIR__ . '/config/auth.php';
require_role(['admin']);
require_once __DIR__ . '/includes/layout.php';
app_top('Respaldo de base de datos','respaldo');
?>
<section class="panel">
    <div class="panel-header">
        <h3>Guardar copia de la base de datos</h3>
    </div>
    <div class="panel-body">
        <div class="alert alert-info">
            Esta opción descarga una copia completa de la base de datos
            <strong>venta_electrodomesticos</strong> en formato SQL.
        </div>

        <p style="margin-bottom:18px">
            El archivo incluirá usuarios, categorías, productos, clientes, ventas y detalle de ventas.
            Puedes volver a importarlo después desde phpMyAdmin.
        </p>

        <a class="btn btn-primary" href="backup.php">💾 Descargar respaldo SQL</a>
    </div>
</section>
<?php app_bottom(); ?>