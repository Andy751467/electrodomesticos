CREATE DATABASE IF NOT EXISTS venta_electrodomesticos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE venta_electrodomesticos;

SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS detalle_venta;
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS categorias;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS usuarios;
SET FOREIGN_KEY_CHECKS=1;

CREATE TABLE usuarios(
 id INT AUTO_INCREMENT PRIMARY KEY,
 nombre VARCHAR(100) NOT NULL,
 usuario VARCHAR(50) NOT NULL UNIQUE,
 password VARCHAR(255) NOT NULL,
 rol ENUM('admin','vendedor') NOT NULL DEFAULT 'vendedor',
 estado TINYINT(1) NOT NULL DEFAULT 1,
 creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE categorias(
 id INT AUTO_INCREMENT PRIMARY KEY,
 nombre VARCHAR(100) NOT NULL UNIQUE,
 descripcion VARCHAR(255) NULL,
 creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE productos(
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
 FOREIGN KEY(categoria_id) REFERENCES categorias(id)
) ENGINE=InnoDB;

CREATE TABLE clientes(
 id INT AUTO_INCREMENT PRIMARY KEY,
 nombres VARCHAR(100) NOT NULL,
 apellidos VARCHAR(100) NULL,
 dni VARCHAR(15) NULL UNIQUE,
 telefono VARCHAR(20) NULL,
 email VARCHAR(120) NULL,
 direccion VARCHAR(200) NULL,
 creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE ventas(
 id INT AUTO_INCREMENT PRIMARY KEY,
 cliente_id INT NULL,
 usuario_id INT NOT NULL,
 fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 total DECIMAL(12,2) NOT NULL DEFAULT 0,
 metodo_pago ENUM('efectivo','yape','plin','tarjeta','transferencia') NOT NULL,
 observacion VARCHAR(255) NULL,
 FOREIGN KEY(cliente_id) REFERENCES clientes(id),
 FOREIGN KEY(usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE TABLE detalle_venta(
 id INT AUTO_INCREMENT PRIMARY KEY,
 venta_id INT NOT NULL,
 producto_id INT NOT NULL,
 cantidad INT NOT NULL,
 precio_unitario DECIMAL(10,2) NOT NULL,
 subtotal DECIMAL(12,2) NOT NULL,
 FOREIGN KEY(venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
 FOREIGN KEY(producto_id) REFERENCES productos(id)
) ENGINE=InnoDB;

INSERT INTO categorias(nombre,descripcion) VALUES
('Televisores','Smart TV y televisores'),
('Refrigeradoras','Refrigeradoras y congeladoras'),
('Cocina','Cocinas, hornos y microondas'),
('Lavado','Lavadoras y secadoras'),
('Pequeños electrodomésticos','Licuadoras, planchas y otros');

INSERT INTO productos(categoria_id,nombre,marca,modelo,precio,stock,descripcion) VALUES
(1,'Smart TV 50 pulgadas','Samsung','UN50',1699.90,10,'Televisor Smart 4K'),
(2,'Refrigeradora No Frost','LG','GT32',2199.00,6,'Refrigeradora 2 puertas'),
(3,'Microondas 20L','Oster','OGM20',399.90,15,'Microondas digital'),
(4,'Lavadora 15Kg','Mabe','LMA15',1499.00,7,'Lavadora automática'),
(5,'Licuadora 1.5L','Oster','BLSTK',289.90,20,'Licuadora de vidrio');

INSERT INTO clientes(nombres,apellidos,dni,telefono,email,direccion) VALUES
('Carlos','Ramirez','70000001','999111222','carlos@gmail.com','Pucallpa'),
('Ana','Torres','70000002','999333444','ana@gmail.com','Yarinacocha');

INSERT INTO usuarios(nombre,usuario,password,rol,estado) VALUES
('Administrador','admin','$2y$12$WhHLA7ZfckzvJrtAnkdGBeLMVUM1Ts/N7P11y/kIw9DnApOgyzsDy','admin',1),
('Vendedor','vendedor','$2y$12$WhHLA7ZfckzvJrtAnkdGBeLMVUM1Ts/N7P11y/kIw9DnApOgyzsDy','vendedor',1);
