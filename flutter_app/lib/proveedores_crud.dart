import 'package:flutter/material.dart';

typedef GuardarProveedor = Future<void> Function(Map<String, dynamic> datos);
typedef ActualizarProveedor = Future<void> Function(
    int id, Map<String, dynamic> datos);
typedef DesactivarProveedor = Future<void> Function(int id);

class ProveedoresCrudPage extends StatefulWidget {
  const ProveedoresCrudPage({
    super.key,
    required this.cargar,
    required this.crear,
    required this.actualizar,
    required this.desactivar,
    required this.puedeEditar,
    required this.alCambiar,
  });

  final Future<List<dynamic>> Function() cargar;
  final GuardarProveedor crear;
  final ActualizarProveedor actualizar;
  final DesactivarProveedor desactivar;
  final bool puedeEditar;
  final VoidCallback alCambiar;

  @override
  State<ProveedoresCrudPage> createState() => _ProveedoresCrudPageState();
}

class _ProveedoresCrudPageState extends State<ProveedoresCrudPage> {
  static const rojo = Color(0xFFDC2626);
  final buscar = TextEditingController();
  List<Map<String, dynamic>> proveedores = [];
  bool cargando = true;
  String? error;
  String filtro = '';

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

  String dato(dynamic valor) => (valor ?? '').toString().trim();
  int numero(dynamic valor) => int.tryParse(dato(valor)) ?? 0;

  void notificar(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    }
  }

  Future<void> cargar() async {
    if (!mounted) return;
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final resultado = await widget.cargar();
      if (!mounted) return;
      setState(() {
        proveedores = resultado
            .map((v) => Map<String, dynamic>.from(v as Map))
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

  Future<void> guardar([Map<String, dynamic>? actual]) async {
    if (!widget.puedeEditar) return;
    final editando = actual != null;
    final id = numero(actual?['id']);
    if (editando && id < 1) return;
    final formKey = GlobalKey<FormState>();

    final razon = TextEditingController(text: dato(actual?['razon_social']));
    final ruc = TextEditingController(text: dato(actual?['ruc']));
    final contacto = TextEditingController(text: dato(actual?['contacto']));
    final telefono = TextEditingController(text: dato(actual?['telefono']));
    final correo = TextEditingController(text: dato(actual?['email']));
    final direccion = TextEditingController(text: dato(actual?['direccion']));
    bool activo = !editando || numero(actual['estado']) == 1;

    String? validarMax(String? v, int n) =>
        (v ?? '').trim().length > n ? 'Máximo $n caracteres' : null;

    try {
      final aceptado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, cambiar) => AlertDialog(
            title: Text(editando ? 'Editar proveedor' : 'Nuevo proveedor'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: razon,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Razón social *',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'La razón social es obligatoria';
                          }
                          return validarMax(v, 150);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: ruc,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'RUC * (11 dígitos)',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                        validator: (v) =>
                            RegExp(r'^[0-9]{11}$').hasMatch((v ?? '').trim())
                                ? null
                                : 'El RUC debe tener 11 dígitos',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: contacto,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Persona de contacto',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => validarMax(v, 120),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: telefono,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) => validarMax(v, 20),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          final texto = (v ?? '').trim();
                          if (texto.isEmpty) return null;
                          if (texto.length > 120) return 'Máximo 120 caracteres';
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(texto)
                              ? null
                              : 'Correo electrónico inválido';
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: direccion,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        validator: (v) => validarMax(v, 220),
                      ),
                      if (editando) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Proveedor activo'),
                          subtitle: Text(
                            activo ? 'Disponible' : 'Proveedor desactivado',
                          ),
                          value: activo,
                          onChanged: (valor) => cambiar(() => activo = valor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                icon: Icon(editando ? Icons.save_outlined : Icons.add),
                label: Text(editando ? 'Guardar cambios' : 'Registrar'),
              ),
            ],
          ),
        ),
      );

      if (aceptado != true) return;
      final datos = <String, dynamic>{
        'razon_social': razon.text.trim(),
        'ruc': ruc.text.trim(),
        'contacto': contacto.text.trim(),
        'telefono': telefono.text.trim(),
        'email': correo.text.trim(),
        'direccion': direccion.text.trim(),
        'estado': activo ? 1 : 0,
      };
      if (editando) {
        await widget.actualizar(id, datos);
      } else {
        await widget.crear(datos);
      }
      notificar(editando
          ? 'Proveedor actualizado correctamente.'
          : 'Proveedor registrado correctamente.');
      await cargar();
      if (mounted) widget.alCambiar();
    } catch (e) {
      notificar('No se pudo guardar: '
          + e.toString().replaceFirst('Exception: ', ''));
    } finally {
      razon.dispose();
      ruc.dispose();
      contacto.dispose();
      telefono.dispose();
      correo.dispose();
      direccion.dispose();
    }
  }

  Future<void> desactivar(Map<String, dynamic> proveedor) async {
    if (!widget.puedeEditar || numero(proveedor['estado']) != 1) return;
    final id = numero(proveedor['id']);
    if (id < 1) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Desactivar proveedor?'),
        content: Text('Se desactivará "${dato(proveedor['razon_social'])}". '
            'La información se conservará y podrás reactivarlo al editar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: rojo),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await widget.desactivar(id);
      notificar('Proveedor desactivado. Puedes reactivarlo al editar.');
      await cargar();
      if (mounted) widget.alCambiar();
    } catch (e) {
      notificar('No se pudo desactivar: '
          + e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget proveedorCard(Map<String, dynamic> p) {
    final activo = numero(p['estado']) == 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE7E9EE)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFEE2E2),
                child: Icon(Icons.local_shipping_outlined, color: rojo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dato(p['razon_social']),
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(width: 6),
              Text(activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                      color: activo ? const Color(0xFF15803D) : rojo,
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Text('RUC: ${dato(p['ruc'])}'),
            if (dato(p['contacto']).isNotEmpty)
              Text('Contacto: ${dato(p['contacto'])}'),
            if (dato(p['telefono']).isNotEmpty)
              Text('Teléfono: ${dato(p['telefono'])}'),
            if (dato(p['email']).isNotEmpty)
              Text('Correo: ${dato(p['email'])}'),
            if (dato(p['direccion']).isNotEmpty)
              Text('Dirección: ${dato(p['direccion'])}'),
            if (widget.puedeEditar) ...[
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  onPressed: () => guardar(p),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(activo ? 'Editar' : 'Editar / reactivar'),
                ),
                if (activo) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => desactivar(p),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Desactivar'),
                    style: TextButton.styleFrom(foregroundColor: rojo),
                  ),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = filtro.trim().toLowerCase();
    final filtrados = proveedores.where((p) {
      final campos = [
        p['razon_social'], p['ruc'], p['contacto'], p['telefono'],
        p['email'], p['direccion'],
      ].map(dato).join(' ').toLowerCase();
      return campos.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Proveedores',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Administra proveedores y sus datos de contacto.'),
          const SizedBox(height: 18),
          TextField(
            controller: buscar,
            onChanged: (v) => setState(() => filtro = v),
            decoration: const InputDecoration(
              labelText: 'Buscar por razón social, RUC o contacto',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (widget.puedeEditar) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => guardar(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo proveedor'),
            ),
          ],
          const SizedBox(height: 16),
          if (cargando) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!, style: const TextStyle(color: rojo)),
            TextButton(onPressed: cargar, child: const Text('Reintentar')),
          ],
          if (!cargando && error == null && filtrados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No se encontraron proveedores.'),
            ),
          if (!cargando && error == null)
            for (final p in filtrados) proveedorCard(p),
          if (!cargando && error == null)
            Text('Mostrando ${filtrados.length} de ${proveedores.length} proveedores',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
        ],
      ),
    );
  }
}
