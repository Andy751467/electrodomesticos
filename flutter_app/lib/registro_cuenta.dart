import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegistroCuentaPage extends StatefulWidget {
  const RegistroCuentaPage({super.key, required this.baseUrl});
  final String baseUrl;

  @override
  State<RegistroCuentaPage> createState() => _RegistroCuentaPageState();
}

class _RegistroCuentaPageState extends State<RegistroCuentaPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _ocultar = true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _usuario.dispose();
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> registrar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _guardando = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse(widget.baseUrl + '/registro.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'nombre': _nombre.text.trim(),
          'usuario': _usuario.text.trim(),
          'password': _clave.text,
          'confirmacion': _confirmacion.text,
        }),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      if (response.statusCode != 201 || body is! Map || body['ok'] != true) {
        setState(() => _error = body is Map
            ? (body['mensaje'] ?? 'No se pudo crear la cuenta').toString()
            : 'No se pudo crear la cuenta');
        return;
      }
      Navigator.pop(context, _usuario.text.trim());
    } on TimeoutException {
      if (mounted) setState(() => _error = 'La conexión tardó demasiado. Revisa XAMPP.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con PHP. Revisa el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFDC2626);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 58, color: rojo),
                    const SizedBox(height: 14),
                    const Text('Únete a ElectroHogar',
                        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Crea tu cuenta de cliente para consultar nuestros productos.'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nombre,
                      enabled: !_guardando,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline), counterText: ''),
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Ingresa tu nombre completo' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usuario,
                      enabled: !_guardando,
                      maxLength: 50,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.alternate_email), counterText: '', helperText: '4 a 50 letras, números, puntos o guiones'),
                      validator: (v) => !RegExp(r'^[A-Za-z0-9_.-]{4,50}$').hasMatch((v ?? '').trim()) ? 'Ingresa un usuario válido' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _clave,
                      enabled: !_guardando,
                      obscureText: _ocultar,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(onPressed: () => setState(() => _ocultar = !_ocultar), icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                      ),
                      validator: (v) {
                        final longitud = utf8.encode(v ?? '').length;
                        return longitud < 8 || longitud > 72 ? 'Usa de 8 a 72 bytes' : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmacion,
                      enabled: !_guardando,
                      obscureText: _ocultar,
                      decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_reset)),
                      validator: (v) => v != _clave.text ? 'Las contraseñas no coinciden' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: const TextStyle(color: rojo)),
                    ],
                    const SizedBox(height: 25),
                    FilledButton.icon(
                      onPressed: _guardando ? null : registrar,
                      icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1),
                      label: Text(_guardando ? 'Creando cuenta...' : 'Crear mi cuenta'),
                    ),
                    TextButton(
                      onPressed: _guardando ? null : () => Navigator.pop(context),
                      child: const Text('Ya tengo una cuenta. Iniciar sesión'),
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

class ClienteCatalogoPage extends StatefulWidget {
  const ClienteCatalogoPage({
    super.key, required this.usuario, required this.cargarProductos, required this.cerrarSesion,
  });
  final Map<String,dynamic> usuario;
  final Future<List<dynamic>> Function() cargarProductos;
  final Future<void> Function() cerrarSesion;

  @override
  State<ClienteCatalogoPage> createState() => _ClienteCatalogoPageState();
}

class _ClienteCatalogoPageState extends State<ClienteCatalogoPage> {
  late Future<List<dynamic>> productos;
  String busqueda = '';
  @override
  void initState() { super.initState(); productos = widget.cargarProductos(); }
  void actualizar() => setState(() => productos = widget.cargarProductos());

  Future<void> salir() async {
    try { await widget.cerrarSesion(); } catch (_) {}
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ElectroHogar | Catálogo'), actions: [
        IconButton(onPressed: actualizar, tooltip: 'Actualizar', icon: const Icon(Icons.refresh)),
        IconButton(onPressed: salir, tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout)),
      ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Hola, ' + (widget.usuario['nombre'] ?? 'Cliente').toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Consulta los electrodomésticos disponibles.'),
            const SizedBox(height: 15),
            TextField(onChanged: (v) => setState(() => busqueda = v.trim().toLowerCase()), decoration: const InputDecoration(labelText: 'Buscar producto', prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 12),
            Expanded(child: FutureBuilder<List<dynamic>>(
              future: productos,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: TextButton(onPressed: actualizar, child: const Text('No se pudo cargar. Reintentar')));
                final lista = (snapshot.data ?? []).whereType<Map>().where((p) => p['estado'].toString() == '1' && [p['nombre'],p['marca'],p['categoria']].join(' ').toLowerCase().contains(busqueda)).toList();
                if (lista.isEmpty) return const Center(child: Text('No hay productos disponibles.'));
                return ListView.builder(itemCount: lista.length, itemBuilder: (context, i) {
                  final p = lista[i];
                  final url = Uri.tryParse((p['imagen'] ?? '').toString());
                  final tieneImagen = url != null && (url.scheme == 'https' || url.scheme == 'http') && url.host.isNotEmpty;
                  final precio = double.tryParse(p['precio'].toString()) ?? 0;
                  return Card(child: ListTile(
                    leading: tieneImagen ? SizedBox(width: 52, height: 52, child: Image.network(url.toString(), fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.inventory_2_outlined))) : const Icon(Icons.inventory_2_outlined),
                    title: Text((p['nombre'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text((p['marca'] ?? '').toString()),
                    trailing: Text('S/ ' + precio.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ));
                });
              },
            )),
          ]),
        ),
      ),
    );
  }
}
