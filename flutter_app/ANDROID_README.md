# ElectroHogar — Aplicación móvil Android (APK)

**Esta es una aplicación Flutter Android instalable, no una página de Chrome.**

Incluye el mismo login, dashboard y módulos Flutter, con conexión a la API PHP/MySQL existente. La pantalla de acceso en Android tiene el botón **Cambiar servidor** para indicar dónde está XAMPP.

## Opción recomendada: APK sin Android Studio ni emulador

1. Abre el repositorio \`Andy751467/electrodomesticos\` en GitHub.
2. Entra a la pestaña **Actions**.
3. Selecciona el flujo **ElectroHogar - APK Android**.
4. Abre su ejecución más reciente que haya finalizado en verde o utiliza **Run workflow** en la rama **main**.
5. En la sección **Artifacts**, descarga **ElectroHogar-APK-Android**.
6. Extrae el ZIP descargado: dentro encontrarás **app-debug.apk**.
7. Transfiere el APK al celular Samsung. Ábrelo e instálalo. Android puede solicitar permiso para instalar aplicaciones de esa fuente: concédelo únicamente si confías en este APK generado de tu propio repositorio.

**Nota:** el flujo debe terminar correctamente antes de que exista un APK descargable. Si la compilación falla, revisa el registro del flujo en Actions. No es un APK firmado para publicar en Play Store, sino una versión de pruebas para presentar al profesor.

## Alternativa: generar el APK en Windows

Necesitas Flutter, Android SDK y Java configurados. No es obligatorio abrir el emulador.

Abre PowerShell en la carpeta raíz del proyecto y ejecuta:

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\flutter_app\crear_apk_android.ps1"
\`\`\`

Si todo compila, se crea \`C:\Users\ASUS\Downloads\ElectroHogar-Android.apk\`.

## Conectar el celular a XAMPP/MySQL

**Ojo:** la app Android no puede usar \`localhost\` para acceder al XAMPP que está en tu laptop. Necesita la **IP IPv4 local de la laptop**.

1. Enciende Apache y MySQL en XAMPP y conecta laptop y Samsung al **mismo Wi-Fi**.
2. Abre PowerShell en la laptop y escribe \`ipconfig\`. Busca **Dirección IPv4**, por ejemplo \`192.168.1.25\`. La IP exacta varía en cada red.
3. Desde el navegador del Samsung abre \`http://TU_IP/electrohogar_profesor/api/login.php\`. Una respuesta JSON «Método no permitido» confirma que el celular puede alcanzar la API (porque el acceso por navegador es GET).
4. Abre **ElectroHogar** en el Samsung. En el login pulsa **Cambiar** junto a Servidor PHP.
5. Escribe \`http://TU_IP/electrohogar_profesor/api\` y pulsa Guardar.
6. Inicia sesión con un usuario existente en tu MySQL.

Si no carga desde el Samsung: revisa si Apache escucha en el puerto 80, si Windows Firewall permite conexiones de la red privada, y si los dos equipos usan el mismo Wi-Fi sin aislamiento de dispositivos. Si tu XAMPP utiliza un puerto diferente (por ejemplo 8080), añádelo a la IP. Si cambias el nombre de la carpeta del proyecto, ajusta esa parte de la dirección.

**La laptop/XAMPP debe seguir encendida para que la app consulte la base de datos.** Para usarla fuera de esa red hay que publicar la API en un hosting seguro con HTTPS.

## Seguridad

Se permite HTTP local solo para desarrollo y demostración; no lo uses con datos reales fuera de una red confiable. Para producción cambia a HTTPS, configura el servidor público y retira el permiso \`usesCleartextTraffic\`.

## Estructura

- \`lib/main.dart\`: login y API; configuración de IP en Android.
- \`lib/dashboard_plus.dart\`: dashboard responsive.
- \`lib/productos_crud.dart\`: CRUD de productos.
- \`config/AndroidManifest.xml\`: permisos Android.
- \`.github/workflows/electrohogar-android-apk.yml\`: compilación de APK en la nube.
