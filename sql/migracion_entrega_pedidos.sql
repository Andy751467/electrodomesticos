-- ElectroHogar: agregar modalidad de entrega a pedidos existentes.
-- Seleccionar primero la base de datos venta_electrodomesticos en phpMyAdmin.
-- No elimina pedidos, ventas ni clientes.
ALTER TABLE pedidos_cliente
  ADD COLUMN tipo_entrega ENUM('recojo','delivery') NOT NULL DEFAULT 'recojo',
  ADD COLUMN direccion_entrega VARCHAR(255) NULL DEFAULT NULL,
  ADD COLUMN referencia_entrega VARCHAR(180) NULL DEFAULT NULL;
