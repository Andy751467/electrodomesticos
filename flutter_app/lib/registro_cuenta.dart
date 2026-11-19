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
    super.key,
    required this.usuario,
    required this.cargarProductos,
    required this.cerrarSesion,
  });

  final Map<String, dynamic> usuario;
  final Future<List<dynamic>> Function() cargarProductos;
  final Future<void> Function() cerrarSesion;

  @override
  State<ClienteCatalogoPage> createState() => _ClienteCatalogoPageState();
}

class _ClienteCatalogoPageState extends State<ClienteCatalogoPage> {
  static const rojo = Color(0xFFDC2626);
  static const negro = Color(0xFF171717);
  late Future<List<dynamic>> productos;
  final favoritos = <int>{};
  final carrito = <int, int>{};
  final buscar = TextEditingController();
  int pestana = 0;
  String categoria = '';
  bool saliendo = false;

  @override
  void initState() {
    super.initState();
    productos = widget.cargarProductos();
  }

  @override
  void dispose() {
    buscar.dispose();
    super.dispose();
  }

  String texto(dynamic v, [String defecto = '']) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? defecto : t;
  }

  int id(Map p) => int.tryParse(texto(p['id'])) ?? 0;
  double precio(Map p) => double.tryParse(texto(p['precio'])) ?? 0;
  String soles(double v) => 'S/ ' + v.toStringAsFixed(2);

  void actualizar() => setState(() => productos = widget.cargarProductos());

  void navegar(int i) {
    FocusScope.of(context).unfocus();
    setState(() => pestana = i);
  }

  void mensaje(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  void agregar(Map p) {
    final clave = id(p);
    if (clave <= 0) return;
    if ((carrito[clave] ?? 0) >= 99) {
      mensaje('El máximo es 99 unidades por producto.');
      return;
    }
    setState(() => carrito[clave] = (carrito[clave] ?? 0) + 1);
    mensaje('Producto agregado al carrito');
  }

  void cambiarCantidad(int clave, int cambio) {
    setState(() {
      final n = (carrito[clave] ?? 0) + cambio;
      if (n <= 0) {
        carrito.remove(clave);
      } else if (n <= 99) {
        carrito[clave] = n;
      }
    });
  }

  void alternarFavorito(int clave) {
    setState(() {
      if (!favoritos.add(clave)) favoritos.remove(clave);
    });
  }

  Future<void> salir() async {
    if (saliendo) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Tu carrito y favoritos de esta sesión se perderán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    if (!mounted || confirma != true) return;
    setState(() => saliendo = true);
    try {
      await widget.cerrarSesion();
    } catch (_) {
      // ApiService limpia la cookie local incluso si el servidor no responde.
    }
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  Widget foto(Map p, {double altura = 120, double? ancho}) {
    final url = Uri.tryParse(texto(p['imagen']));
    final uriValida = url != null &&
        (url.scheme == 'http' || url.scheme == 'https') &&
        url.host.isNotEmpty;
    final alternativa = Center(
      child: Icon(Icons.devices_other_outlined, size: altura > 100 ? 45 : 28,
          color: const Color(0xFF9CA3AF)),
    );
    return Container(
      height: altura,
      width: ancho ?? double.infinity,
      color: const Color(0xFFF5F6F8),
      child: uriValida
          ? Image.network(url.toString(), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => alternativa)
          : alternativa,
    );
  }

  Future<void> detalle(Map p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(16), child: foto(p, altura: 225)),
            const SizedBox(height: 18),
            Text(texto(p['categoria'], 'Electrodomésticos'),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(texto(p['nombre'], 'Producto'),
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            Text([texto(p['marca']), texto(p['modelo'])].where((t) => t.isNotEmpty).join(' · ')),
            const SizedBox(height: 14),
            Text(soles(precio(p)), style: const TextStyle(color: rojo, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Descripción', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(texto(p['descripcion'], 'Consulta las características de este producto en la tienda.')),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () { Navigator.pop(ctx); agregar(p); },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Agregar al carrito'),
            ),
          ],
        ),
      ),
    );
  }

  Widget tarjeta(Map p) {
    final marcado = favoritos.contains(id(p));
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(children: [
            InkWell(onTap: () => detalle(p), child: foto(p, altura: 112)),
            Positioned(top: 4, right: 4, child: IconButton.filledTonal(
              tooltip: marcado ? 'Quitar de favoritos' : 'Agregar a favoritos',
              onPressed: () => alternarFavorito(id(p)),
              icon: Icon(marcado ? Icons.favorite : Icons.favorite_border,
                  color: marcado ? rojo : negro, size: 19),
            )),
          ]),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => detalle(p),
                  child: Text(texto(p['nombre'], 'Producto'), maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                Text(texto(p['marca']), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF667085), fontSize: 12)),
                const Spacer(),
                Text(soles(precio(p)), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: rojo, fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => detalle(p),
                    child: const Text('Ver detalle'),
                  )),
                  IconButton(
                    tooltip: 'Agregar al carrito',
                    onPressed: () => agregar(p),
                    icon: const Icon(Icons.add_shopping_cart, color: rojo),
                  ),
                ]),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget cuadricula(List<Map> lista) {
    if (lista.isEmpty) return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: Text('No se encontraron productos.')));
    return LayoutBuilder(builder: (context, box) {
      final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columnas = box.maxWidth < 330 || escala > 1.25 ? 1 : box.maxWidth > 850 ? 4 : box.maxWidth > 550 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnas, crossAxisSpacing: 12, mainAxisSpacing: 12,
          mainAxisExtent: 286.0 + (escala > 1 ? (escala - 1) * 120.0 : 0.0),
        ),
        itemCount: lista.length,
        itemBuilder: (_, i) => tarjeta(lista[i]),
      );
    });
  }

  Widget categorias(List<Map> lista) {
    final nombres = lista.map((p) => texto(p['categoria'])).where((s) => s.isNotEmpty).toSet().toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final nombre in ['', ...nombres])
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(nombre.isEmpty ? 'Todos' : nombre),
            selected: categoria == nombre,
            onSelected: (_) { setState(() { categoria = nombre; pestana = 1; }); },
          )),
      ]),
    );
  }

  Widget inicio(List<Map> lista) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Color(0xFF171717), Color(0xFF991B1B)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TU TIENDA DE ELECTRODOMÉSTICOS', style: TextStyle(color: Color(0xFFFECACA), fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 12),
          Text('Hola, ' + texto(widget.usuario['nombre'], 'Cliente'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Encuentra lo que necesitas para tu hogar.', style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () { setState(() { buscar.clear(); categoria = ''; pestana = 1; }); },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Explorar catálogo'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: negro),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      const Text('Categorías', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      categorias(lista),
      const SizedBox(height: 19),
      Row(children: [
        const Expanded(child: Text('Descubre productos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
        TextButton(onPressed: () { setState(() { buscar.clear(); categoria = ''; pestana = 1; }); }, child: const Text('Ver todos')),
      ]),
      const SizedBox(height: 7),
      cuadricula(lista.take(6).toList()),
    ]);
  }

  Widget catalogo(List<Map> lista) {
    final q = buscar.text.trim().toLowerCase();
    final filtrada = lista.where((p) => (categoria.isEmpty || texto(p['categoria']) == categoria) &&
        [p['nombre'], p['marca'], p['categoria'], p['modelo']].map((v) => texto(v).toLowerCase()).join(' ').contains(q)).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Catálogo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      TextField(controller: buscar, onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: 'Buscar nombre o marca', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(tooltip: 'Limpiar búsqueda', onPressed: () => setState(buscar.clear), icon: const Icon(Icons.close)))),
      const SizedBox(height: 13),
      categorias(lista),
      const SizedBox(height: 12),
      Text('${filtrada.length} productos'),
      const SizedBox(height: 12),
      cuadricula(filtrada),
    ]);
  }

  Widget vistaFavoritos(List<Map> lista) {
    final elegidos = lista.where((p) => favoritos.contains(id(p))).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Mis favoritos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (elegidos.isEmpty) const Text('Pulsa el corazón de un producto para guardarlo aquí.')
      else cuadricula(elegidos),
    ]);
  }

  Widget vistaCarrito(List<Map> lista) {
    final elegidos = lista.where((p) => carrito.containsKey(id(p))).toList();
    final total = elegidos.fold<double>(0, (s, p) => s + precio(p) * (carrito[id(p)] ?? 0));
    final noDisponibles = carrito.keys.where((clave) => !lista.any((p) => id(p) == clave)).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Mi carrito', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (elegidos.isEmpty) ...[
        const Padding(padding: EdgeInsets.all(24), child: Icon(Icons.shopping_cart_outlined, size: 62, color: Colors.grey)),
        const Center(child: Text('Tu carrito está vacío')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => navegar(1), child: const Text('Explorar productos')),
      ],
      for (final p in elegidos)
        Card(
          color: Colors.white,
          child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: foto(p, altura: 65, ancho: 65)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(texto(p['nombre']), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(soles(precio(p)), style: const TextStyle(color: rojo)),
              ])),
              IconButton(tooltip: 'Quitar producto', onPressed: () => setState(() => carrito.remove(id(p))), icon: const Icon(Icons.delete_outline)),
            ]),
            Row(children: [
              IconButton(tooltip: 'Disminuir cantidad', onPressed: () => cambiarCantidad(id(p), -1), icon: const Icon(Icons.remove_circle_outline)),
              Text((carrito[id(p)] ?? 0).toString()),
              IconButton(tooltip: 'Aumentar cantidad', onPressed: () => cambiarCantidad(id(p), 1), icon: const Icon(Icons.add_circle_outline)),
              Expanded(child: Text(soles(precio(p) * (carrito[id(p)] ?? 0)), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ])),
        ),
      if (noDisponibles.isNotEmpty) ...[
        const Text('Algunos artículos ya no están en el catálogo.'),
        TextButton(onPressed: () => setState(() { for (final clave in noDisponibles) { carrito.remove(clave); } }), child: const Text('Quitar artículos no disponibles')),
      ],
      if (elegidos.isNotEmpty) ...[
        const SizedBox(height: 18),
        Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('Total estimado', style: TextStyle(fontWeight: FontWeight.bold))),
              Text(soles(total), style: const TextStyle(fontSize: 22, color: rojo, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            const Text('Carrito de esta sesión. No reserva stock ni envía pedidos. El pago y la confirmación de compra aún no están habilitados.', style: TextStyle(color: Color(0xFF667085))),
          ]),
        )),
      ],
    ]);
  }

  Widget perfil() {
    return ListView(padding: const EdgeInsets.all(22), children: [
      const CircleAvatar(radius: 40, backgroundColor: Color(0xFFFEE2E2), child: Icon(Icons.person_outline, size: 39, color: rojo)),
      const SizedBox(height: 15),
      Text(texto(widget.usuario['nombre'], 'Cliente'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Card(color: Colors.white, child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Usuario'), subtitle: Text(texto(widget.usuario['usuario'], 'Cliente'))),
        const Divider(height: 1),
        const ListTile(leading: Icon(Icons.verified_user_outlined), title: Text('Tipo de cuenta'), subtitle: Text('Cliente')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.favorite_border), title: const Text('Mis favoritos'), onTap: () => navegar(2), trailing: const Icon(Icons.chevron_right)),
      ])),
      const SizedBox(height: 22),
      OutlinedButton.icon(onPressed: saliendo ? null : salir, icon: const Icon(Icons.logout), label: const Text('Cerrar sesión')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cantidad = carrito.values.fold<int>(0, (s, n) => s + n);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('ElectroHogar'),
        actions: [
          IconButton(onPressed: actualizar, tooltip: 'Actualizar catálogo', icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => navegar(3), tooltip: 'Mi carrito',
            icon: Badge(isLabelVisible: cantidad > 0, label: Text(cantidad.toString()), child: const Icon(Icons.shopping_cart_outlined))),
        ],
      ),
      body: SafeArea(
        child: pestana == 4 ? perfil() : FutureBuilder<List<dynamic>>(
          future: productos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Center(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 10),
                const Text('No se pudo cargar el catálogo. Revisa la conexión con XAMPP.', textAlign: TextAlign.center),
                TextButton(onPressed: actualizar, child: const Text('Reintentar')),
              ]),
            ));
            final lista = (snapshot.data ?? []).whereType<Map>().where((p) => id(p) > 0 && texto(p['estado']) == '1').toList();
            return switch (pestana) {
              1 => catalogo(lista),
              2 => vistaFavoritos(lista),
              3 => vistaCarrito(lista),
              _ => inicio(lista),
            };
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pestana,
        onDestinationSelected: navegar,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Carrito'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
