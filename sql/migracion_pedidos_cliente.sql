-- Migración no destructiva para ElectroHogar.
CREATE TABLE IF NOT EXISTS pedidos_cliente (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  clave_peticion CHAR(32) NOT NULL,
  metodo_pago ENUM('efectivo','yape','plin','transferencia') NOT NULL,
  referencia VARCHAR(120) NULL,
  total DECIMAL(12,2) NOT NULL,
  estado ENUM('pendiente','confirmado','rechazado') NOT NULL DEFAULT 'pendiente',
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  verificado_por INT NULL,
  fecha_revision DATETIME NULL,
  venta_id INT NULL,
  UNIQUE KEY uq_pedido_peticion (usuario_id, clave_peticion),
  KEY idx_pedido_estado (estado, fecha),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  FOREIGN KEY (verificado_por) REFERENCES usuarios(id),
  FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_pedido_cliente (
  pedido_id INT NOT NULL,
  producto_id INT NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (pedido_id, producto_id),
  FOREIGN KEY (pedido_id) REFERENCES pedidos_cliente(id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
