import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_plus.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/http_client_io.dart' if (dart.library.html) 'services/http_client_web.dart' as client_factory;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.initialize();
  runApp(const ElectroHogarApp());
}

class ElectroHogarApp extends StatelessWidget {
  const ElectroHogarApp({super.key});

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFDC2626);
    const negro = Color(0xFF0A0A0A);

    return MaterialApp(
      title: 'ElectroHogar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: rojo),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: negro,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: rojo,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: rojo, width: 2),
          ),
        ),
      ),
      home: const LoginPage(),
      routes: {'/login': (_) => const LoginPage()},
    );
  }
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String _webUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost/electrohogar_profesor/api',
  );

  // En el emulador Android 10.0.2.2 apunta a la PC.
  // En un telefono real se debe configurar la IP local de la PC.
  static const String _androidDefault =
      'http://10.0.2.2/electrohogar_profesor/api';

  String _serverUrl = kIsWeb ? _webUrl : _androidDefault;
  String get baseUrl => _serverUrl;

  Future<void> initialize() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('electrohogar_server_url');
    if (saved != null && saved.isNotEmpty) _serverUrl = saved;
  }

  Future<void> changeServerUrl(String rawUrl) async {
    final url = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty ||
        !parsed.path.endsWith('/api')) {
      throw const FormatException(
        'La direccion debe terminar en /api. Ejemplo: '
        'http://192.168.1.5/electrohogar_profesor/api',
      );
    }
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('electrohogar_server_url', url);
    }
    _cookie = null;
    _serverUrl = url;
  }

  final http.Client _client = client_factory.createApiClient();
  String? _cookie;

  Map<String, String> get headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        if (_cookie != null) 'Cookie': _cookie!,
      };

  Future<Map<String, dynamic>> login(String usuario, String password) async {
    final response = await _client.post(
      Uri.parse(baseUrl + '/login.php'),
      headers: headers,
      body: jsonEncode({
        'usuario': usuario,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _cookie = setCookie.split(';').first;
    }

    final body = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300 || body['ok'] != true || body['data'] is! Map) {
      throw Exception(body['mensaje'] ?? 'No se pudo iniciar sesión');
    }

    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _client.get(
      Uri.parse(baseUrl + '/dashboard.php'),
      headers: headers,
    );

    final body = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['mensaje'] ?? 'No se pudo cargar el dashboard');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<List<dynamic>> productos({String q = ''}) async {
    final uri = Uri.parse(baseUrl + '/productos.php').replace(
      queryParameters: q.trim().isEmpty ? null : {'q': q.trim()},
    );

    final response = await _client.get(uri, headers: headers);
    final body = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['mensaje'] ?? 'No se pudieron cargar los productos');
    }

    return List<dynamic>.from(body['data'] ?? []);
  }

  // Operaciones CRUD de productos; el backend exige rol de administrador.
  Future<String> guardarProducto(Map<String, dynamic> datos, int? id) async {
    final uri = Uri.parse(baseUrl + '/productos.php');
    final payload = <String, dynamic>{
      ...datos,
      if (id != null) 'id': id,
    };
    final response = id == null
        ? await _client.post(
            uri, headers: headers, body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 15))
        : await _client.put(
            uri, headers: headers, body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se pudo guardar el producto');
    }
    return (body['mensaje'] ?? 'Producto guardado').toString();
  }

  Future<String> eliminarProducto(int id) async {
    final response = await _client.delete(
      Uri.parse(baseUrl + '/productos.php'),
      headers: headers,
      body: jsonEncode({'id': id}),
    ).timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se pudo eliminar el producto');
    }
    return (body['mensaje'] ?? 'Producto eliminado').toString();
  }

  // Consultas de los módulos del dashboard.
  Future<List<dynamic>> listarModulo(String archivo) async {
    const permitidos = {
      'clientes.php', 'ventas.php', 'proveedores.php', 'categorias.php'
    };
    if (!permitidos.contains(archivo)) {
      throw Exception('Módulo no autorizado');
    }
    final response = await _client.get(
      Uri.parse(baseUrl + '/' + archivo),
      headers: headers,
    ).timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se pudieron consultar los datos');
    }
    return List<dynamic>.from(body['data'] ?? []);
  }

  Future<void> crearCliente(Map<String, dynamic> datos) async {
    final response = await _client.post(
      Uri.parse(baseUrl + '/clientes.php'),
      headers: headers,
      body: jsonEncode(datos),
    ).timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se pudo registrar el cliente');
    }
  }

  Future<Map<String, dynamic>> detalleVenta(int id) async {
    final response = await _client.get(
      Uri.parse(baseUrl + '/ventas.php?id=' + id.toString()),
      headers: headers,
    ).timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['mensaje'] ?? 'No se pudo consultar la venta');
    }
    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<void> logout() async {
    try {
      await _client.post(
        Uri.parse(baseUrl + '/logout.php'),
        headers: headers,
      );
    } finally {
      _cookie = null;
    }
  }

  Map<String, dynamic> _decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return {
      'ok': false,
      'mensaje': 'La API no devolvió JSON válido. Verifica Apache y la URL.'
    };
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usuarioCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool cargando = false;
  bool ocultar = true;
  String? error;

  @override
  void dispose() {
    usuarioCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> configurarServidor() async {
    final controller = TextEditingController(
      text: ApiService.instance.baseUrl,
    );
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Conectar con XAMPP'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conecta el telefono y la laptop a la misma red Wi-Fi. '
                  'Enciende Apache y MySQL en la computadora.',
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'URL del servidor PHP',
                    hintText: 'http://192.168.1.5/electrohogar_profesor/api',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Usa la direccion IPv4 de la PC, no localhost '
                  'ni 10.0.2.2 en un celular fisico.',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ApiService.instance.changeServerUrl(controller.text);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(
                        e.toString().replaceFirst('FormatException: ', ''),
                      )),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (result == true && mounted) {
        setState(() => error = null);
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> ingresar() async {
    if (cargando) return;
    if (usuarioCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => error = 'Ingresa tu usuario y contraseña.');
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final usuario = await ApiService.instance.login(
        usuarioCtrl.text.trim(),
        passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ElectroDashboardPlus(
            usuario: usuario,
            loadDashboard: () => ApiService.instance.dashboard(),
            loadProducts: () => ApiService.instance.productos(),
            saveProduct: ApiService.instance.guardarProducto,
            deleteProduct: ApiService.instance.eliminarProducto,
            loadModule: ApiService.instance.listarModulo,
            createClient: ApiService.instance.crearCliente,
            loadSale: ApiService.instance.detalleVenta,
            logout: ApiService.instance.logout,
          ),
        ),
      );
    } on TimeoutException {
      if (mounted) {
        setState(() =>
            error = 'La conexión tardó demasiado. Revisa Apache y XAMPP.');
      }
    } catch (e) {
      if (!mounted) return;
      final detalle = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        error = detalle.contains('SocketException') ||
                detalle.contains('ClientException') ||
                detalle.contains('XMLHttpRequest')
            ? 'No se pudo conectar con el servidor PHP. Verifica XAMPP y localhost.'
            : detalle;
      });
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Widget _brandLogo({double size = 54}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/logo-electrohogar.jpg',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.home_work_outlined,
            color: Color(0xFFDC2626),
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _brandName({double fontSize = 23}) {
    return Text.rich(
      TextSpan(
        children: const [
          TextSpan(text: 'Electro', style: TextStyle(color: Colors.white)),
          TextSpan(
            text: 'Hogar',
            style: TextStyle(color: Color(0xFFF87171)),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -.5,
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0x26EF4444),
              border: Border.all(color: const Color(0x44EF4444)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFFF87171), size: 19),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBrand() {
    return Container(
      color: const Color(0xFF111114),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -160,
            top: -180,
            child: Container(
              width: 480,
              height: 480,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x50DC2626), Color(0x00111114)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -170,
            bottom: -270,
            child: Container(
              width: 530,
              height: 530,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x33DC2626), Color(0x00111114)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 54,
              vertical: 42,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _brandLogo(size: 59),
                    const SizedBox(width: 14),
                    _brandName(),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1FEF4444),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x55EF4444)),
                  ),
                  child: const Text(
                    'GESTIÓN COMERCIAL INTELIGENTE',
                    style: TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Tu negocio,\nbajo control.',
                  style: TextStyle(
                    fontSize: 47,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.7,
                    height: 1.08,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Administra productos, clientes y ventas '
                  'desde un solo lugar, de forma fácil y organizada.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFB8BBC5),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),
                _feature(Icons.inventory_2_outlined, 'Control de inventario'),
                _feature(Icons.groups_outlined, 'Gestión de clientes'),
                _feature(Icons.insights_outlined, 'Resumen de ventas'),
                const Spacer(),
                const Text(
                  'ELECTROHOGAR  •  SISTEMA DE VENTAS E INVENTARIO',
                  style: TextStyle(
                    color: Color(0xFF8D919B),
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileBrand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 34, 25, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111114), Color(0xFF380D12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _brandLogo(size: 52),
              const SizedBox(width: 13),
              _brandName(fontSize: 25),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Sistema de Ventas e Inventario',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginForm() {
    const text = Color(0xFF171717);
    const muted = Color(0xFF6B7280);
    const red = Color(0xFFDC2626);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'BIENVENIDO DE NUEVO',
                style: TextStyle(
                  color: red,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: text,
                  letterSpacing: -.9,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ingresa tus credenciales para acceder al sistema ElectroHogar.',
                style: TextStyle(
                  color: muted,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 34),
              const Text(
                'Usuario',
                style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: usuarioCtrl,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Ingresa tu usuario',
                  prefixIcon: const Icon(Icons.person_outline),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                ),
              ),
              const SizedBox(height: 21),
              const Text(
                'Contraseña',
                style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: passwordCtrl,
                obscureText: ocultar,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => ingresar(),
                decoration: InputDecoration(
                  hintText: 'Ingresa tu contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  suffixIcon: IconButton(
                    tooltip: ocultar
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () => setState(() => ocultar = !ocultar),
                    icon: Icon(
                      ocultar
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '¿Olvidaste tu acceso? Consulta con el administrador.',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: muted, fontSize: 11.5),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_outlined,
                          color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Servidor PHP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text(
                              ApiService.instance.baseUrl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: configurarServidor,
                        child: const Text('Cambiar'),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    border: Border.all(color: const Color(0xFFFECACA)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB91C1C),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 55,
                child: FilledButton(
                  onPressed: cargando ? null : ingresar,
                  style: FilledButton.styleFrom(
                    backgroundColor: red,
                    disabledBackgroundColor: const Color(0xFFB74C4C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    elevation: 2,
                  ),
                  child: cargando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ingresar al sistema',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 25),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13),
                    child: Text(
                      'Acceso para usuarios autorizados',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                ],
              ),
              const SizedBox(height: 27),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Administrador  •  Vendedor  •  Cliente',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                '© 2026 ElectroHogar. Todos los derechos reservados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final minHeight =
              constraints.maxHeight < 710 ? 710.0 : constraints.maxHeight;
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: wide
                    ? SizedBox(
                        height: minHeight,
                        child: Row(
                          children: [
                            Expanded(flex: 11, child: _desktopBrand()),
                            Expanded(
                              flex: 10,
                              child: ColoredBox(
                                color: Colors.white,
                                child: _loginForm(),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _mobileBrand(),
                          Container(
                            color: Colors.white,
                            width: double.infinity,
                            child: _loginForm(),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const DashboardPage({
    super.key,
    required this.usuario,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? data;
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await ApiService.instance.dashboard();
      if (!mounted) return;
      setState(() => data = resultado);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  Future<void> salir() async {
    await ApiService.instance.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.usuario['nombre']?.toString() ?? 'Usuario';
    final rol = widget.usuario['rol']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ElectroHogar'),
        actions: [
          IconButton(
            onPressed: cargar,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: salir,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0A0A),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset('assets/logo-electrohogar.jpg'),
                  ),
                ),
                accountName: Text(nombre),
                accountEmail: Text('Rol: ' + rol),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Dashboard'),
                selected: true,
                selectedColor: const Color(0xFFDC2626),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Productos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductosPage(),
                    ),
                  );
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Color(0xFFDC2626),
                ),
                title: const Text('Cerrar sesión'),
                onTap: salir,
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: cargar,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Hola, ' + nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rol: ' + rol,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (cargando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              ErrorCard(
                mensaje: error!,
                onRetry: cargar,
              )
            else
              DashboardCards(data: data ?? const {}),
          ],
        ),
      ),
    );
  }
}

class DashboardCards extends StatelessWidget {
  final Map<String, dynamic> data;

  const DashboardCards({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      DashboardItem(
        titulo: 'Productos',
        valor: (data['total_productos'] ?? 0).toString(),
        icono: Icons.inventory_2_outlined,
      ),
      DashboardItem(
        titulo: 'Clientes',
        valor: (data['total_clientes'] ?? 0).toString(),
        icono: Icons.people_outline,
      ),
      DashboardItem(
        titulo: 'Ventas',
        valor: (data['total_ventas'] ?? 0).toString(),
        icono: Icons.shopping_cart_outlined,
      ),
      DashboardItem(
        titulo: 'Ingresos',
        valor: 'S/ ' + (data['ingresos'] ?? 0).toString(),
        icono: Icons.payments_outlined,
      ),
      DashboardItem(
        titulo: 'Stock bajo',
        valor: (data['stock_bajo'] ?? 0).toString(),
        icono: Icons.warning_amber_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 700 ? 3 : 2;
        final ancho =
            (constraints.maxWidth - ((columnas - 1) * 12)) / columnas;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: ancho,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.icono,
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item.titulo,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.valor,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class DashboardItem {
  final String titulo;
  final String valor;
  final IconData icono;

  DashboardItem({
    required this.titulo,
    required this.valor,
    required this.icono,
  });
}

class ErrorCard extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;

  const ErrorCard({
    super.key,
    required this.mensaje,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              mensaje,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final buscarCtrl = TextEditingController();

  List<dynamic> productos = [];
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultado = await ApiService.instance.productos(
        q: buscarCtrl.text,
      );

      if (!mounted) return;
      setState(() => productos = resultado);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
      ),
      body: RefreshIndicator(
        onRefresh: cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: buscarCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => cargar(),
              decoration: InputDecoration(
                labelText: 'Buscar por SKU, nombre o marca',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: cargar,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (cargando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              ErrorCard(
                mensaje: error!,
                onRetry: cargar,
              )
            else if (productos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text('No hay productos registrados.'),
                ),
              )
            else
              for (final item in productos)
                ProductoCard(
                  producto: Map<String, dynamic>.from(item as Map),
                ),
          ],
        ),
      ),
    );
  }
}

class ProductoCard extends StatelessWidget {
  final Map<String, dynamic> producto;

  const ProductoCard({
    super.key,
    required this.producto,
  });

  @override
  Widget build(BuildContext context) {
    final stock = int.tryParse((producto['stock'] ?? 0).toString()) ?? 0;
    final minimo =
        int.tryParse((producto['stock_minimo'] ?? 0).toString()) ?? 0;
    final bajo = stock <= minimo;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: bajo
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF5F5F5),
          child: Icon(
            Icons.inventory_2_outlined,
            color: bajo
                ? const Color(0xFFDC2626)
                : const Color(0xFF171717),
          ),
        ),
        title: Text(
          (producto['nombre'] ?? 'Producto').toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            (producto['codigo_sku'] ?? '-').toString() +
                ' · ' +
                (producto['marca'] ?? '').toString() +
                '\nStock: ' +
                stock.toString() +
                ' · Mínimo: ' +
                minimo.toString(),
          ),
        ),
        isThreeLine: true,
        trailing: Text(
          'S/ ' + (producto['precio'] ?? '0.00').toString(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
