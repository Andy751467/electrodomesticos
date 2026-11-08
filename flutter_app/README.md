# ElectroHogar - Flutter Web en Chrome y localhost

Este paquete se conecta al backend PHP/MySQL existente en XAMPP. No requiere Android Studio ni emulador.

## Funciones del proyecto
- Login de ElectroHogar conectado a api/login.php.
- Sesion PHP persistida mediante cookies en Chrome.
- Dashboard de productos, clientes, ventas, ingresos y stock bajo.
- Consulta y busqueda de productos.
- Cerrar sesion.
- Colores negro y rojo.

## Requisitos
- Windows, Chrome y Flutter SDK.
- Apache y MySQL encendidos en XAMPP.
- Base de datos venta_electrodomesticos correctamente instalada.

## Ejecutar en Google Chrome

Abre PowerShell dentro de flutter_app y ejecuta este unico comando:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\run_chrome.ps1"
```

El script busca Flutter instalado, configura Flutter Web, crea plataforma web si hace falta, instala dependencias y abre Chrome en http://localhost:7357.

## Conexion con PHP

El script usa el nombre de la carpeta padre de flutter_app para formar la API, por ejemplo:
http://localhost/electrohogar_profesor/api

Antes de iniciar, comprueba que puedes abrir http://localhost/electrohogar_profesor/ en Chrome. Si el proyecto usa otra carpeta en htdocs, el script la detectara.

El script cambia solo la cabecera CORS antigua de config/helpers.php si sigue usando un asterisco (wildcard), y antes guarda una copia *.copia_antes_flutter. Flutter Web envia la cookie PHPSESSID usando BrowserClient con credenciales.

Para desarrollo usa la misma palabra localhost para Chrome y la API. Esto no necesita 10.0.2.2 (solo Android).

Importante: configura contrasenas seguras antes de usar este proyecto fuera de localhost.


## Nuevo panel Flutter Web (noviembre 2026)

Desde la pantalla de login se abre un dashboard renovado:
- Menú lateral oscuro en escritorio y menú adaptable en móvil.
- Resumen con productos, clientes, ventas, ingresos y stock mínimo.
- Accesos rápidos y últimas ventas reales.
- Alertas de stock con datos del inventario.
- Páginas de consulta: productos, categorías, clientes, ventas y proveedores.
- Búsqueda en cada listado.
- Registro de clientes desde Flutter Web (administrador o vendedor).
- Detalle de cada venta.
- Reportes de ingresos por mes, métodos de pago y productos más vendidos.
- Cierre de sesión real mediante la API PHP.

Las métricas adicionales requieren la versión nueva de api/dashboard.php.
Los listados de ventas, clientes y proveedores respetan los permisos de
admin/vendedor establecidos en PHP. La aplicación web sigue siendo PHP + MySQL.

Para actualizar una instalación local existente, copia de la rama main:
  flutter_app/lib/main.dart
  flutter_app/lib/dashboard_plus.dart
  api/dashboard.php

Después ejecuta en flutter_app:
  flutter pub get
  flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=API_URL=http://localhost/electrohogar_profesor/api

Antes de abrir la app, inicia Apache y MySQL en XAMPP.
