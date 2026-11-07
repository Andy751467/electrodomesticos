import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
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
    );
  }
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2/electrodomesticos/api',
  );

  final http.Client _client = http.Client();
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
    );

    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _cookie = setCookie.split(';').first;
    }

    final body = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['mensaje'] ?? 'No se pudo iniciar sesión');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
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
  final usuarioCtrl = TextEditingController(text: 'admin');
  final passwordCtrl = TextEditingController(text: 'admin123');

  bool cargando = false;
  bool ocultar = true;
  String? error;

  @override
  void dispose() {
    usuarioCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> ingresar() async {
    if (usuarioCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => error = 'Ingresa usuario y contraseña.');
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
          builder: (_) => DashboardPage(usuario: usuario),
        ),
      );
    } catch (e) {
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 8,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xFF0A0A0A),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Image.asset(
                              'assets/logo-electrohogar.jpg',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'ElectroHogar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sistema de Ventas e Inventario',
                            style: TextStyle(color: Color(0xFFD4D4D4)),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: usuarioCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: ocultar,
                            onSubmitted: (_) => ingresar(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() => ocultar = !ocultar);
                                },
                                icon: Icon(
                                  ocultar
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: cargando ? null : ingresar,
                            icon: cargando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              cargando ? 'Ingresando...' : 'Ingresar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
