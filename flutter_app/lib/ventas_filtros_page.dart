import 'package:flutter/material.dart';

typedef CargarVentas = Future<List<dynamic>> Function({
  String? desde,
  String? hasta,
  String? cliente,
  String? metodoPago,
});

class VentasFiltrosPage extends StatefulWidget {
  const VentasFiltrosPage({
    super.key,
    required this.cargar,
    required this.verDetalle,
  });

  final CargarVentas cargar;
  final Future<void> Function(int id) verDetalle;

  @override
  State<VentasFiltrosPage> createState() => _VentasFiltrosPageState();
}

class _VentasFiltrosPageState extends State<VentasFiltrosPage> {
  static const Color rojo = Color(0xFFDC2626);
  static const Color secundario = Color(0xFF667085);
  static const Color borde = Color(0xFFE7E9EE);

  final TextEditingController clienteCtrl = TextEditingController();
  DateTime? desde;
  DateTime? hasta;
  String metodoPago = '';
  List<Map<String, dynamic>> ventas = [];
  bool cargando = false;
  String? error;

  static const metodos = <String, String>{
    '': 'Todos los métodos',
    'efectivo': 'Efectivo',
    'yape': 'Yape',
    'plin': 'Plin',
    'tarjeta': 'Tarjeta',
    'transferencia': 'Transferencia',
  };

  @override
  void initState() {
    super.initState();
    buscar();
  }

  @override
  void dispose() {
    clienteCtrl.dispose();
    super.dispose();
  }

  String texto(dynamic valor) => (valor ?? '').toString().trim();

  int entero(dynamic valor) => int.tryParse(texto(valor)) ?? 0;

  double importe(dynamic valor) => double.tryParse(texto(valor)) ?? 0;

  String dinero(dynamic valor) => 'S/ ${importe(valor).toStringAsFixed(2)}';

  String fechaSql(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  String fechaLegible(DateTime? valor) =>
      valor == null ? 'Sin seleccionar' : fechaSql(valor);

  Future<void> elegirFecha(bool inicial) async {
    final actual = inicial ? desde : hasta;
    final seleccion = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: inicial ? 'Fecha desde' : 'Fecha hasta',
    );
    if (seleccion == null || !mounted) return;
    setState(() {
      if (inicial) {
        desde = seleccion;
      } else {
        hasta = seleccion;
      }
    });
  }

  Future<void> buscar() async {
    if (cargando) return;
    if (desde != null && hasta != null && desde!.isAfter(hasta!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'La fecha inicial no puede ser posterior a la fecha final.',
        )),
      );
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final resultado = await widget.cargar(
        desde: desde == null ? null : fechaSql(desde!),
        hasta: hasta == null ? null : fechaSql(hasta!),
        cliente: clienteCtrl.text.trim(),
        metodoPago: metodoPago,
      );
      if (!mounted) return;
      setState(() {
        ventas = resultado
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void limpiar() {
    clienteCtrl.clear();
    setState(() {
      desde = null;
      hasta = null;
      metodoPago = '';
    });
    buscar();
  }

  Widget selectorFecha(String titulo, DateTime? valor, bool inicial) {
    return OutlinedButton.icon(
      onPressed: () => elegirFecha(inicial),
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text('$titulo: ${fechaLegible(valor)}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF20242B),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: const BorderSide(color: borde),
      ),
    );
  }

  Widget encabezado() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Filtrar ventas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: clienteCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => buscar(),
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Cliente',
              hintText: 'Nombre, apellido, DNI o usuario',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              selectorFecha('Desde', desde, true),
              selectorFecha('Hasta', hasta, false),
              if (desde != null || hasta != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    desde = null;
                    hasta = null;
                  }),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Quitar fechas'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('metodo-$metodoPago'),
            initialValue: metodoPago,
            decoration: const InputDecoration(
              labelText: 'Método de pago',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            items: [
              for (final entry in metodos.entries)
                DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
            onChanged: (v) => setState(() => metodoPago = v ?? ''),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: cargando ? null : buscar,
                icon: const Icon(Icons.search),
                label: const Text('Buscar ventas'),
              ),
              OutlinedButton.icon(
                onPressed: cargando ? null : limpiar,
                icon: const Icon(Icons.refresh),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget ventaCard(Map<String, dynamic> venta) {
    final id = entero(venta['id']);
    final cliente = texto(venta['cliente']);
    final metodo = texto(venta['metodo_pago']);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borde),
      ),
      child: InkWell(
        onTap: id < 1 ? null : () => widget.verDetalle(id),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: rojo),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Venta #$id',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    dinero(venta['total']),
                    style: const TextStyle(
                      color: rojo,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                'Cliente: ${cliente.isEmpty ? 'Sin cliente asignado' : cliente}',
              ),
              const SizedBox(height: 4),
              Text(
                'Fecha: ${texto(venta['fecha'])}',
                style: const TextStyle(color: secundario),
              ),
              const SizedBox(height: 4),
              Text(
                'Pago: ${metodos[metodo] ?? metodo}',
                style: const TextStyle(color: secundario),
              ),
              const SizedBox(height: 7),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver detalle',
                    style: TextStyle(color: rojo, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.chevron_right, color: rojo),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suma = ventas.fold<double>(
      0,
      (acumulado, venta) => acumulado + importe(venta['total']),
    );

    return RefreshIndicator(
      onRefresh: buscar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Historial de ventas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Consulta por fecha, cliente y método de pago.',
            style: TextStyle(color: secundario),
          ),
          const SizedBox(height: 18),
          encabezado(),
          const SizedBox(height: 18),
          if (cargando) const LinearProgressIndicator(),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: rojo)),
            TextButton.icon(
              onPressed: buscar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
          if (!cargando && error == null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text('${ventas.length} ventas encontradas'),
                ),
                Chip(
                  avatar: const Icon(Icons.account_balance_wallet_outlined,
                      size: 18),
                  label: Text('Total: ${dinero(suma)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ventas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No se encontraron ventas con estos filtros.'),
                ),
              )
            else
              for (final venta in ventas) ventaCard(venta),
          ],
        ],
      ),
    );
  }
}
