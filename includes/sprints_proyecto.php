<?php
// Estado visual del proyecto para el Dashboard.
// Mantener estos valores si el proyecto académico está completamente finalizado.
$totalSprints = 150;
$sprintsTerminados = 150;
$porcentajeSprints = $totalSprints > 0
    ? min(100, (int)round(($sprintsTerminados / $totalSprints) * 100))
    : 0;
?>
<style>
.proyecto-sprints{
    background:#fff;
    border:1px solid #e5e7eb;
    border-radius:18px;
    box-shadow:0 8px 24px rgba(15,23,42,.06);
    padding:20px 22px;
    margin-bottom:24px;
    display:grid;
    grid-template-columns:minmax(230px,1.15fr) repeat(2,minmax(120px,.55fr)) minmax(300px,1.5fr) auto;
    gap:18px;
    align-items:center;
}
.proyecto-sprints__titulo{
    display:flex;
    align-items:center;
    gap:14px;
}
.proyecto-sprints__icono{
    width:52px;
    height:52px;
    border-radius:15px;
    display:grid;
    place-items:center;
    background:linear-gradient(135deg,#eef2ff,#ede9fe);
    color:#6d28d9;
    font-size:25px;
    flex:0 0 auto;
}
.proyecto-sprints h3{
    margin:0;
    font-size:18px;
    color:#111827;
}
.proyecto-sprints p{
    margin:5px 0 0;
    color:#6b7280;
    font-size:12px;
}
.proyecto-sprints__stat{
    min-height:70px;
    border-radius:14px;
    display:flex;
    flex-direction:column;
    align-items:center;
    justify-content:center;
    border:1px solid #e5e7eb;
    background:#f8fafc;
}
.proyecto-sprints__stat strong{
    display:block;
    font-size:27px;
    line-height:1;
    margin-bottom:6px;
}
.proyecto-sprints__stat span{
    color:#64748b;
    font-size:12px;
    font-weight:600;
}
.proyecto-sprints__stat--total strong{color:#2563eb}
.proyecto-sprints__stat--ok{
    background:#f0fdf4;
    border-color:#dcfce7;
}
.proyecto-sprints__stat--ok strong{color:#16a34a}
.proyecto-sprints__avance{
    min-width:0;
}
.proyecto-sprints__avance-top{
    display:flex;
    justify-content:space-between;
    gap:12px;
    align-items:center;
    margin-bottom:9px;
    color:#334155;
    font-size:12px;
    font-weight:700;
}
.proyecto-sprints__barra{
    height:12px;
    border-radius:999px;
    background:#e5e7eb;
    overflow:hidden;
    box-shadow:inset 0 1px 2px rgba(15,23,42,.08);
}
.proyecto-sprints__relleno{
    height:100%;
    width:<?= $porcentajeSprints ?>%;
    background:linear-gradient(90deg,#16a34a,#22c55e);
    border-radius:999px;
    transition:width .4s ease;
}
.proyecto-sprints__detalle{
    margin-top:7px;
    display:flex;
    justify-content:space-between;
    color:#64748b;
    font-size:11px;
}
.proyecto-sprints__estado{
    display:flex;
    align-items:center;
    gap:9px;
    padding:13px 15px;
    border-radius:14px;
    background:#ecfdf5;
    color:#15803d;
    border:1px solid #dcfce7;
    font-size:13px;
    font-weight:800;
    white-space:nowrap;
}
.proyecto-sprints__check{
    width:28px;
    height:28px;
    border-radius:50%;
    display:grid;
    place-items:center;
    background:#16a34a;
    color:#fff;
    font-size:14px;
}
@media (max-width:1250px){
    .proyecto-sprints{
        grid-template-columns:1fr 1fr 1fr;
    }
    .proyecto-sprints__titulo,
    .proyecto-sprints__avance{
        grid-column:span 2;
    }
}
@media (max-width:800px){
    .proyecto-sprints{
        grid-template-columns:1fr 1fr;
        padding:16px;
    }
    .proyecto-sprints__titulo,
    .proyecto-sprints__avance,
    .proyecto-sprints__estado{
        grid-column:1 / -1;
    }
}
@media (max-width:520px){
    .proyecto-sprints{
        grid-template-columns:1fr;
    }
    .proyecto-sprints__titulo,
    .proyecto-sprints__avance,
    .proyecto-sprints__estado{
        grid-column:auto;
    }
}
</style>

<section class="proyecto-sprints" aria-label="Estado de sprints del proyecto">
    <div class="proyecto-sprints__titulo">
        <div class="proyecto-sprints__icono">🚀</div>
        <div>
            <h3>Estado del proyecto</h3>
            <p>Seguimiento general de los sprints de desarrollo</p>
        </div>
    </div>

    <div class="proyecto-sprints__stat proyecto-sprints__stat--total">
        <strong><?= $totalSprints ?></strong>
        <span>Sprints totales</span>
    </div>

    <div class="proyecto-sprints__stat proyecto-sprints__stat--ok">
        <strong><?= $sprintsTerminados ?></strong>
        <span>Terminados</span>
    </div>

    <div class="proyecto-sprints__avance">
        <div class="proyecto-sprints__avance-top">
            <span>Progreso general</span>
            <span><?= $sprintsTerminados ?> / <?= $totalSprints ?></span>
        </div>

        <div class="proyecto-sprints__barra">
            <div class="proyecto-sprints__relleno"></div>
        </div>

        <div class="proyecto-sprints__detalle">
            <span>Implementación completada</span>
            <strong><?= $porcentajeSprints ?>%</strong>
        </div>
    </div>

    <div class="proyecto-sprints__estado">
        <span class="proyecto-sprints__check">✓</span>
        <span>Sprints terminados</span>
    </div>
</section>