import 'package:flutter/material.dart';

const _rojo = Color(0xFFDC2626);
const _negro = Color(0xFF171717);
const _gris = Color(0xFF667085);
const _borde = Color(0xFFE5E7EB);

String texto(dynamic value, [String fallback = '']) {
  final result = (value ?? '').toString().trim();
  return result.isEmpty ? fallback : result;
}

int numero(dynamic value) => int.tryParse(texto(value)) ?? 0;
double decimal(dynamic value) =>
    double.tryParse(texto(value).replaceAll(',', '.')) ?? 0;
String soles(dynamic value) => 'S/ ' + decimal(value).toStringAsFixed(2);

class ProductosCrudPage extends StatefulWidget {
  const ProductosCrudPage({
    super.key,
    required this.puedeEditar,
    required this.cargarProductos,
    required this.cargarCategorias,
    required this.guardar,
    required this.eliminar,
    required this.actualizarResumen,
  });

  final bool puedeEditar;
  final Future<List<dynamic>> Function() cargarProductos;
  final Future<List<dynamic>> Function() cargarCategorias;
  final Future<String> Function(Map<String, dynamic>, int?) guardar;
  final Future<String> Function(int) eliminar;
  final VoidCallback actualizarResumen;

  @override
  State<ProductosCrudPage> createState() => _ProductosCrudPageState();
}

class _ProductosCrudPageState extends State<ProductosCrudPage> {
  final buscar = TextEditingController();
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> categorias = [];
  bool cargando = true;
  String? error;
  String filtro = 'todos';

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    buscar.dispose();
    super.dispose();
  }

  bool activo(Map<String, dynamic> p) => numero(p['estado']) == 1;
  bool bajo(Map<String, dynamic> p) =>
      activo(p) && numero(p['stock']) <= numero(p['stock_minimo']);

  String categoriaDe(Map<String, dynamic> p) {
    if (texto(p['categoria']).isNotEmpty) return texto(p['categoria']);
    for (final c in categorias) {
      if (numero(c['id']) == numero(p['categoria_id'])) {
        return texto(c['nombre']);
      }
    }
    return 'Sin categoría';
  }

  Future<void> cargar() async {
    if (!mounted) return;
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final res = await Future.wait<List<dynamic>>([
        widget.cargarProductos(),
        widget.cargarCategorias(),
      ]);
      if (!mounted) return;
      setState(() {
        productos = res[0]
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        categorias = res[1]
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void mensaje(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Map<String, dynamic>> get visibles {
    final q = buscar.text.trim().toLowerCase();
    return productos.where((p) {
      final match = switch (filtro) {
        'activos' => activo(p),
        'inactivos' => !activo(p),
        'stock' => bajo(p),
        _ => true,
      };
      final contenido = [
        p['codigo_sku'], p['nombre'], p['marca'],
        p['modelo'], categoriaDe(p),
      ].map((v) => texto(v).toLowerCase()).join(' ');
      return match && contenido.contains(q);
    }).toList();
  }

  Future<void> formulario([Map<String, dynamic>? p]) async {
    if (!widget.puedeEditar) return;
    if (categorias.isEmpty) {
      mensaje('Primero registra una categoría en el sistema.');
      return;
    }
    final editando = p != null;
    final formKey = GlobalKey<FormState>();
    final sku = TextEditingController(text: texto(p?['codigo_sku']));
    final nombre = TextEditingController(text: texto(p?['nombre']));
    final marca = TextEditingController(text: texto(p?['marca']));
    final modelo = TextEditingController(text: texto(p?['modelo']));
    final precio = TextEditingController(
        text: editando ? decimal(p['precio']).toStringAsFixed(2) : '');
    final stock = TextEditingController(
        text: editando ? texto(p['stock'], '0') : '0');
    final minimo = TextEditingController(
        text: editando ? texto(p['stock_minimo'], '5') : '5');
    final descripcion =
        TextEditingController(text: texto(p?['descripcion']));
    int? categoria = editando ? numero(p['categoria_id']) : null;
    if (categoria != null &&
        !categorias.any((c) => numero(c['id']) == categoria)) {
      categoria = null;
    }
    bool habilitado = editando ? activo(p) : true;
    bool guardando = false;
    String? fallo;

    try {
      final resultado = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, actualizarDialogo) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.inventory_2_outlined, color: _rojo),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  editando ? 'Editar producto' : 'Registrar producto')),
            ]),
            content: SizedBox(
              width: 570,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: categoria,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categorias.map((c) => DropdownMenuItem<int>(
                          value: numero(c['id']),
                          child: Text(texto(c['nombre']),
                              overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: guardando ? null :
                            (id) => actualizarDialogo(() => categoria = id),
                        validator: (id) =>
                            id == null ? 'Selecciona una categoría' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sku,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: 'Código SKU *',
                          hintText: 'TV-SAM-001',
                          prefixIcon: Icon(Icons.qr_code),
                          counterText: '',
                        ),
                        validator: (value) {
                          final t = (value ?? '').trim();
                          if (!RegExp(r'^[A-Za-z0-9_-]{2,50}$').hasMatch(t)) {
                            return 'Usa 2-50 letras, números o guiones';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nombre,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          prefixIcon: Icon(Icons.sell_outlined),
                          counterText: '',
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty
                                ? 'Ingresa el nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: marca,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Marca *',
                          prefixIcon: Icon(Icons.business_outlined),
                          counterText: '',
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty
                                ? 'Ingresa la marca' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modelo,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Modelo (opcional)',
                          prefixIcon: Icon(Icons.devices_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: precio,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio (S/) *',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) {
                          final t = (value ?? '').trim().replaceAll(',', '.');
                          final amount = double.tryParse(t);
                          if (amount == null || !amount.isFinite) {
                            return 'Ingresa un precio válido';
                          }
                          if (amount < 0 || amount > 99999999.99) {
                            return 'Precio fuera de rango';
                          }
                          if (!RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(t)) {
                            return 'Máximo 2 decimales';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock *',
                          prefixIcon: Icon(Icons.inventory_outlined),
                        ),
                        validator: (value) {
                          final n = int.tryParse((value ?? '').trim());
                          return n == null || n < 0 || n > 100000000
                              ? 'Ingresa un número entero no negativo' : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: minimo,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock mínimo *',
                          prefixIcon: Icon(Icons.warning_amber_outlined),
                        ),
                        validator: (value) {
                          final n = int.tryParse((value ?? '').trim());
                          return n == null || n < 0 || n > 100000000
                              ? 'Ingresa un número entero no negativo' : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descripcion,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      if (editando)
                        SwitchListTile.adaptive(
                          title: const Text('Producto activo'),
                          subtitle: const Text(
                              'Puedes reactivar productos desactivados.'),
                          value: habilitado,
                          activeColor: _rojo,
                          onChanged: guardando ? null : (v) =>
                              actualizarDialogo(() => habilitado = v),
                        ),
                      if (fallo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(fallo!,
                              style: const TextStyle(color: _rojo)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null :
                    () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: guardando ? null : () async {
                  if (!(formKey.currentState?.validate() ?? false) ||
                      categoria == null) return;
                  actualizarDialogo(() {
                    guardando = true;
                    fallo = null;
                  });
                  try {
                    final res = await widget.guardar({
                      'categoria_id': categoria,
                      'codigo_sku': sku.text.trim().toUpperCase(),
                      'nombre': nombre.text.trim(),
                      'marca': marca.text.trim(),
                      'modelo': modelo.text.trim(),
                      'precio': double.parse(
                          precio.text.trim().replaceAll(',', '.')),
                      'stock': int.parse(stock.text.trim()),
                      'stock_minimo': int.parse(minimo.text.trim()),
                      'descripcion': descripcion.text.trim(),
                      'imagen': editando ? p['imagen'] : null,
                      'estado': habilitado ? 1 : 0,
                    }, editando ? numero(p['id']) : null);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, res);
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      actualizarDialogo(() => fallo =
                          e.toString().replaceFirst('Exception: ', ''));
                    }
                  } finally {
                    if (dialogContext.mounted) {
                      actualizarDialogo(() => guardando = false);
                    }
                  }
                },
                icon: guardando
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(guardando ? 'Guardando...' : 'Guardar producto'),
              ),
            ],
          ),
        ),
      );
      if (resultado != null && mounted) {
        mensaje(resultado);
        await cargar();
        widget.actualizarResumen();
      }
    } finally {
      sku.dispose();
      nombre.dispose();
      marca.dispose();
      modelo.dispose();
      precio.dispose();
      stock.dispose();
      minimo.dispose();
      descripcion.dispose();
    }
  }

  Future<void> borrar(Map<String, dynamic> p) async {
    if (!widget.puedeEditar) return;
    final id = numero(p['id']);
    if (id <= 0) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Deseas eliminar "' + texto(p['nombre']) + '"?\n\n'
          'Si este producto tiene ventas, se desactivará para '
          'conservar el historial del negocio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      final res = await widget.eliminar(id);
      if (!mounted) return;
      mensaje(res);
      await cargar();
      widget.actualizarResumen();
    } catch (e) {
      mensaje('Error: ' + e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget contador(String title, int value, IconData icon, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borde),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                fontSize: 11, color: _gris)),
            const SizedBox(height: 4),
            Text(value.toString(), style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        )),
      ]),
    );
  }

  Widget tarjeta(Map<String, dynamic> p) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _borde),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                height: 46, width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.devices_other_outlined, color: _rojo),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  texto(p['nombre'], 'Producto'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15,
                  ),
                ),
              ),
              if (widget.puedeEditar)
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete',
                        child: Text('Eliminar o desactivar')),
                  ],
                  onSelected: (choice) {
                    if (choice == 'edit') formulario(p);
                    if (choice == 'delete') borrar(p);
                  },
                ),
            ]),
            const SizedBox(height: 12),
            Text('SKU: ' + texto(p['codigo_sku'], '-'),
                style: const TextStyle(color: _gris, fontSize: 12)),
            const SizedBox(height: 6),
            Text(categoriaDe(p) + ' · ' + texto(p['marca'], '-'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _gris, fontSize: 12)),
            const Spacer(),
            const Divider(color: _borde),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(soles(p['precio']),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 20)),
                Text('Stock: ' + texto(p['stock'], '0'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 7, children: [
              Chip(
                label: Text(activo(p) ? 'Activo' : 'Inactivo',
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                backgroundColor: activo(p)
                    ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                side: BorderSide.none,
              ),
              if (bajo(p))
                const Chip(
                  label: Text('Stock bajo', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Color(0xFFFFEDD5),
                  side: BorderSide.none,
                ),
            ]),
            if (widget.puedeEditar)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => formulario(p),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Editar producto'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = visibles;
    final activos = productos.where(activo).length;
    final alertas = productos.where(bajo).length;
    return RefreshIndicator(
      onRefresh: cargar,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Wrap(
            spacing: 16, runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestión de productos', style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: _negro)),
                  SizedBox(height: 5),
                  Text('Catálogo, precios, inventario y categorías',
                      style: TextStyle(color: _gris, fontSize: 13)),
                ],
              ),
              if (widget.puedeEditar)
                FilledButton.icon(
                  onPressed: cargando ? null : () => formulario(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo producto'),
                  style: FilledButton.styleFrom(backgroundColor: _rojo),
                ),
            ],
          ),
          const SizedBox(height: 19),
          if (!widget.puedeEditar)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text('Solo el administrador puede modificar productos.',
                  style: TextStyle(color: _gris)),
            ),
          Wrap(spacing: 11, runSpacing: 11, children: [
            contador('Total', productos.length, Icons.inventory_2_outlined,
                const Color(0xFF2563EB)),
            contador('Activos', activos, Icons.check_circle_outline,
                const Color(0xFF16A34A)),
            contador('Stock bajo', alertas, Icons.warning_amber_outlined,
                const Color(0xFFEA580C)),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white,
                border: Border.all(color: _borde),
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: buscar,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por SKU, nombre, marca o categoría',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Actualizar',
                      onPressed: cargar,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 7, children: [
                  for (final f in [
                    ('todos', 'Todos'), ('activos', 'Activos'),
                    ('inactivos', 'Inactivos'), ('stock', 'Stock bajo'),
                  ])
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: filtro == f.$1,
                      selectedColor: const Color(0xFFFEE2E2),
                      onSelected: (_) => setState(() => filtro = f.$1),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 17),
          if (cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(35),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Card(
              color: const Color(0xFFFFF1F2),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(error!, style: const TextStyle(color: _rojo)),
                  TextButton(onPressed: cargar,
                      child: const Text('Reintentar')),
                ]),
              ),
            )
          else if (filtrados.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(30),
              child: Text('No se encontraron productos.'),
            ))
          else
            LayoutBuilder(builder: (context, box) {
              final columns =
                  box.maxWidth >= 1100 ? 3 : box.maxWidth >= 700 ? 2 : 1;
              const gap = 13.0;
              final width = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final p in filtrados)
                  SizedBox(
                    width: width,
                    height: widget.puedeEditar ? 315 : 260,
                    child: tarjeta(p),
                  ),
              ]);
            }),
          const SizedBox(height: 12),
          Text('Mostrando ' + filtrados.length.toString() +
              ' de ' + productos.length.toString() + ' productos',
              textAlign: TextAlign.end,
              style: const TextStyle(color: _gris, fontSize: 12)),
        ],
      ),
    );
  }
}
