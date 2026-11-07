# ElectroHogar Mobile - Flutter

La pagina web principal sigue funcionando con PHP + MySQL.

Esta carpeta agrega una aplicacion movil Flutter conectada a la misma API.

## Incluye

- Login usando los mismos usuarios de ElectroHogar.
- Sesion PHP reutilizada desde Flutter.
- Dashboard con productos, clientes, ventas, ingresos y stock bajo.
- Listado y busqueda de productos.
- Paleta negro y rojo.
- Cierre de sesion.

## Preparar el proyecto

Abre PowerShell en:

C:\xampp\htdocs\electrodomesticos_git\flutter_app

Ejecuta:

.\setup.ps1

Luego inicia un emulador Android y ejecuta:

flutter run

## Conexion con XAMPP

Para el emulador Android se usa:

http://10.0.2.2/electrodomesticos/api

10.0.2.2 representa el localhost de tu computadora desde el emulador Android.

Si usas un celular fisico conectado al mismo Wi-Fi, ejecuta Flutter indicando la IP local de tu PC:

flutter run --dart-define=API_URL=http://TU_IP/electrodomesticos/api

Ejemplo:

flutter run --dart-define=API_URL=http://192.168.1.20/electrodomesticos/api
