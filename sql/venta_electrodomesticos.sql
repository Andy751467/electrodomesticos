CREATE DATABASE IF NOT EXISTS venta_electrodomesticos
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE venta_electrodomesticos;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS detalle_venta;
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS categorias;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS usuarios;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    usuario VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    rol ENUM('admin','vendedor') NOT NULL DEFAULT 'vendedor',
    estado TINYINT(1) NOT NULL DEFAULT 1,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE categorias (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE productos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    categoria_id INT NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    marca VARCHAR(80) NOT NULL,
    modelo VARCHAR(80) NULL,
    precio DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    descripcion TEXT NULL,
    imagen VARCHAR(255) NULL,
    estado TINYINT(1) NOT NULL DEFAULT 1,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_producto_categoria (categoria_id),
    INDEX idx_producto_nombre (nombre),
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
) ENGINE=InnoDB;

CREATE TABLE clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NULL,
    dni VARCHAR(15) NULL UNIQUE,
    telefono VARCHAR(20) NULL,
    email VARCHAR(120) NULL,
    direccion VARCHAR(200) NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE ventas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NULL,
    usuario_id INT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    metodo_pago ENUM('efectivo','yape','plin','tarjeta','transferencia') NOT NULL,
    observacion VARCHAR(255) NULL,
    INDEX idx_venta_fecha (fecha),
    INDEX idx_venta_cliente (cliente_id),
    CONSTRAINT fk_venta_cliente
        FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    CONSTRAINT fk_venta_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE detalle_venta (
    id INT AUTO_INCREMENT PRIMARY KEY,
    venta_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    INDEX idx_detalle_venta (venta_id),
    INDEX idx_detalle_producto (producto_id),
    CONSTRAINT fk_detalle_venta
        FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (producto_id) REFERENCES productos(id)
) ENGINE=InnoDB;

INSERT INTO usuarios(nombre, usuario, password, rol, estado) VALUES
('Administrador', 'admin', '$2y$12$e3cFMGgW.tefvg.B3oSeTOmSlnyasAXOT57qjTcU9Xs40GKAYl9yC', 'admin', 1),
('Vendedor Principal', 'vendedor', '$2y$12$e3cFMGgW.tefvg.B3oSeTOmSlnyasAXOT57qjTcU9Xs40GKAYl9yC', 'vendedor', 1);

INSERT INTO categorias(nombre, descripcion) VALUES
('Televisores', 'Smart TV y televisores'),
('Refrigeradoras', 'Refrigeradoras y congeladoras'),
('Cocina', 'Cocinas, hornos y microondas'),
('Lavado', 'Lavadoras y secadoras'),
('Pequeños electrodomésticos', 'Licuadoras, planchas y otros');

INSERT INTO productos(categoria_id, nombre, marca, modelo, precio, stock, descripcion, estado) VALUES
(1, 'Smart TV 50 pulgadas', 'Samsung', 'UN50', 1699.90, 9, 'Televisor Smart 4K', 1),
(2, 'Refrigeradora No Frost', 'LG', 'GT32', 2199.00, 6, 'Refrigeradora de 2 puertas', 1),
(3, 'Microondas 20L', 'Oster', 'OGM20', 399.90, 14, 'Microondas digital', 1),
(4, 'Lavadora 15Kg', 'Mabe', 'LMA15', 1499.00, 7, 'Lavadora automática', 1),
(5, 'Licuadora 1.5L', 'Oster', 'BLSTK', 289.90, 3, 'Licuadora con vaso de vidrio', 1);

INSERT INTO clientes(nombres, apellidos, dni, telefono, email, direccion) VALUES
('Carlos', 'Ramirez', '70000001', '999111222', 'carlos@gmail.com', 'Pucallpa'),
('Ana', 'Torres', '70000002', '999333444', 'ana@gmail.com', 'Yarinacocha');

INSERT INTO ventas(cliente_id, usuario_id, fecha, total, metodo_pago, observacion) VALUES
(1, 1, NOW(), 1699.90, 'yape', 'Venta inicial de demostración'),
(2, 1, NOW(), 689.80, 'efectivo', 'Venta inicial de demostración');

INSERT INTO detalle_venta(venta_id, producto_id, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 1, 1699.90, 1699.90),
(2, 3, 1, 399.90, 399.90),
(2, 5, 1, 289.90, 289.90);

SELECT 'Base de datos creada correctamente' AS mensaje;
SELECT COUNT(*) AS total_productos FROM productos;
SELECT COUNT(*) AS total_clientes FROM clientes;
SELECT COUNT(*) AS total_ventas FROM ventas;
SELECT SUM(total) AS ingresos FROM ventas;
