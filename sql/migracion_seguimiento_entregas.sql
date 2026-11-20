-- ElectroHogar: seguimiento logístico de pedidos.
-- Ejecutar una sola vez en venta_electrodomesticos desde phpMyAdmin.
-- Primero respaldar la base de datos. No elimina ventas ni pedidos.
-- REQUISITO: pedidos_cliente y migracion_entrega_pedidos.sql ya aplicadas.
ALTER TABLE pedidos_cliente
  ADD COLUMN estado_entrega ENUM(
    'pendiente','preparando','enviado','listo_recojo','entregado'
  ) NOT NULL DEFAULT 'pendiente',
  ADD COLUMN fecha_estado_entrega DATETIME NULL DEFAULT NULL;

-- Comprobar luego desde phpMyAdmin:
-- SELECT id, estado, tipo_entrega, estado_entrega,
--        fecha_estado_entrega FROM pedidos_cliente ORDER BY id DESC LIMIT 10;
