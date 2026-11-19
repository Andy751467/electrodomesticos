import 'dart:math';
import 'package:flutter/material.dart';

typedef EnviarPedido = Future<Map<String, dynamic>> Function(Map<String, dynamic>);
typedef CargarPedidos = Future<List<dynamic>> Function();
typedef RevisarPedido = Future<void> Function(int id, String accion);

const metodosPedido = <String, String>{
  'efectivo': 'Efectivo',
  'yape': 'Yape',
  'plin': 'Plin',
  'transferencia': 'Transferencia bancaria',
};

String dineroPedido(dynamic v) =>
    'S/ ${(double.tryParse(v.toString()) ?? 0).toStringAsFixed(2)}';

class PagoPedidoPage extends StatefulWidget {
  const PagoPedidoPage({super.key, required this.detalle,
    required this.totalCentavos, required this.enviar});
  final List<Map<String, dynamic>> detalle;
  final int totalCentavos;
  final EnviarPedido enviar;

  @override
  State<PagoPedidoPage> createState() => _PagoPedidoPageState();
}

class _PagoPedidoPageState extends State<PagoPedidoPage> {
  final referencia = TextEditingController();
  late final String clave;
  String metodo = 'efectivo';
  bool enviando = false;
  bool intento = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final random = Random.secure();
    clave = List.generate(16, (_) => random.nextInt(256)
        .toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() { referencia.dispose(); super.dispose(); }

  String get instruccion => switch(metodo) {
    'yape' => 'Coordina con la tienda el número o QR oficial de Yape. No envíes dinero a un número no verificado.',
    'plin' => 'Solicita a la tienda los datos oficiales de Plin. El pago se comprobará manualmente.',
    'transferencia' => 'Solicita a la tienda su cuenta bancaria oficial. No compartas claves ni códigos de seguridad.',
    _ => 'Paga en efectivo al recoger tu pedido, según lo coordinado con la tienda.',
  };

  Future<void> confirmar() async {
    if (enviando) return;
    FocusScope.of(context).unfocus();
    setState(() { enviando = true; intento = true; error = null; });
    try {
      final result = await widget.enviar({
        'metodo_pago': metodo,
        'referencia': metodo == 'efectivo' ? '' : referencia.text.trim(),
        'clave_peticion': clave,
        'total_centavos': widget.totalCentavos,
        'detalle': widget.detalle,
      });
      if (!mounted) return;
      setState(() => enviando = false);
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        enviando = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !enviando,
    child: Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('¿Cómo deseas pagar?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(child: ListTile(
            title: const Text('Total del pedido'),
            trailing: Text(dineroPedido(widget.totalCentavos / 100),
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 22, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 18),
          for (final entry in metodosPedido.entries)
            Card(
              child: ListTile(
                enabled: !intento,
                leading: Icon(entry.key == metodo ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: entry.key == metodo ? const Color(0xFFDC2626) : Colors.grey),
                title: Text(entry.value),
                trailing: Icon(entry.key == 'efectivo' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined),
                onTap: intento ? null : () => setState(() => metodo = entry.key),
              ),
            ),
          const SizedBox(height: 18),
          Text(instruccion),
          const SizedBox(height: 12),
          if (metodo != 'efectivo') TextField(
            controller: referencia,
            enabled: !intento,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'N.º de operación (opcional)', helperText: 'Solo si ya realizaste el pago'),
          ),
          const SizedBox(height: 12),
          const Text('El pedido quedará pendiente. Esta aplicación no cobra dinero ni verifica pagos automáticamente. El stock no se reserva hasta la confirmación del personal.',
            style: TextStyle(color: Color(0xFF667085))),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
            const Text('Puedes reintentar aquí sin duplicar el pedido. Si sales de esta pantalla, revisa Mis pedidos antes de crear otro.'),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: enviando ? null : confirmar,
            icon: enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
            label: Text(enviando ? 'Registrando...' : 'Confirmar pedido'),
          ),
        ]),
      ))),
    ),
  );
}

class HistorialPedidosPage extends StatefulWidget {
  const HistorialPedidosPage({super.key, required this.cargar, this.revisar, this.alCambiar});
  final CargarPedidos cargar;
  final RevisarPedido? revisar;
  final VoidCallback? alCambiar;

  @override
  State<HistorialPedidosPage> createState() => _HistorialPedidosPageState();
}

class _HistorialPedidosPageState extends State<HistorialPedidosPage> {
  late Future<List<dynamic>> datos;
  bool ocupado = false;

  @override
  void initState() { super.initState(); datos = widget.cargar(); }

  void recargar() => setState(() => datos = widget.cargar());
  String texto(dynamic v) => (v ?? '').toString();

  Future<void> procesar(Map p, String accion) async {
    if (ocupado || widget.revisar == null) return;
    final confirmar = accion == 'confirmar';
    final aceptado = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(confirmar ? 'Verificar pago recibido' : 'Rechazar pedido'),
      content: Text(confirmar
        ? 'Confirma solo si comprobaste que el dinero fue recibido por la tienda. Se registrará una venta y se descontará el stock. Total: ${dineroPedido(p['total'])}.'
        : 'El pedido quedará rechazado. Si el cliente envió dinero, coordina su devolución fuera de la aplicación.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmar ? 'Pago verificado' : 'Rechazar')),
      ],
    ));
    if (aceptado != true || !mounted) return;
    setState(() => ocupado = true);
    try {
      await widget.revisar!(int.parse(texto(p['id'])), accion);
      if (!mounted) return;
      recargar();
      widget.alCambiar?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(confirmar ? 'Venta registrada' : 'Pedido rechazado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: datos,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(snap.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
        TextButton(onPressed: recargar, child: const Text('Reintentar')),
      ])));
      final lista = (snap.data ?? []).whereType<Map>().toList();
      return RefreshIndicator(onRefresh: () async { recargar(); try { await datos; } catch (_) {} },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: Text(widget.revisar == null ? 'Mis pedidos' : 'Pedidos y pagos',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            IconButton(onPressed: recargar, icon: const Icon(Icons.refresh), tooltip: 'Actualizar pedidos'),
          ]),
          const SizedBox(height: 10),
          if (lista.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Todavía no hay pedidos.'))),
          for (final p in lista) Card(
            color: Colors.white,
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Pedido #${p['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                Text(dineroPedido(p['total']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
              ]),
              if (widget.revisar != null) Text('Cliente: ${texto(p['cliente'])}'),
              Text(metodosPedido[texto(p['metodo_pago'])] ?? texto(p['metodo_pago'])),
              Text(texto(p['fecha']), style: const TextStyle(color: Colors.black54)),
              if (texto(p['referencia']).isNotEmpty) Text('Operación informada: ${p['referencia']}'),
              const Divider(),
              for (final it in ((p['detalle'] as List?) ?? []).whereType<Map>())
                Text('${it['cantidad']} × ${it['nombre']}  ·  ${dineroPedido(it['subtotal'])}'),
              const SizedBox(height: 10),
              Chip(label: Text(switch(texto(p['estado'])) {
                'confirmado' => 'Pago verificado',
                'rechazado' => 'Rechazado',
                _ => 'Pendiente de pago',
              })),
              if (p['venta_id'] != null) Text('Venta #${p['venta_id']}'),
              if (widget.revisar == null)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VoucherPedidoPage(
                      pedidoId: p['id'].toString(), cargar: widget.cargar,
                    ),
                  )),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ver voucher'),
                ),
              if (widget.revisar != null && p['estado'] == 'pendiente') Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(onPressed: ocupado ? null : () => procesar(p, 'rechazar'), child: const Text('Rechazar')),
                FilledButton(onPressed: ocupado ? null : () => procesar(p, 'confirmar'), child: const Text('Verificar pago')),
              ]),
            ])),
          ),
        ]),
      );
    },
  );
}

 
class VoucherPedidoPage extends StatefulWidget {
  const VoucherPedidoPage({super.key, required this.pedidoId, required this.cargar});
  final String pedidoId;
  final CargarPedidos cargar;

  @override
  State<VoucherPedidoPage> createState() => _VoucherPedidoPageState();
}

class _VoucherPedidoPageState extends State<VoucherPedidoPage> {
  late Future<Map<String, dynamic>> pedido;

  @override
  void initState() {
    super.initState();
    pedido = buscarPedido();
  }

  Future<Map<String, dynamic>> buscarPedido() async {
    final lista = await widget.cargar();
    for (final p in lista.whereType<Map>()) {
      if (p['id'].toString() == widget.pedidoId) {
        return Map<String, dynamic>.from(p);
      }
    }
    throw Exception('No se encontró el pedido en el historial disponible.');
  }

  void actualizar() => setState(() => pedido = buscarPedido());

  Widget fila(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(etiqueta, style: const TextStyle(color: Color(0xFF667085)))),
      Expanded(child: Text(valor, textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher'), actions: [
        IconButton(onPressed: actualizar, tooltip: 'Actualizar estado',
            icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: pedido,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Padding(padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('No se pudo cargar el voucher. Tu pedido ya registrado puede consultarse en Mis pedidos.',
                      textAlign: TextAlign.center),
                  TextButton(onPressed: actualizar, child: const Text('Reintentar')),
                ]),
              ));
            }
            final p = snap.data!;
            final confirmado = p['estado'] == 'confirmado';
            final rechazado = p['estado'] == 'rechazado';
            final estado = confirmado ? 'Pago verificado' : rechazado ? 'Pedido rechazado' : 'Pendiente de verificación';
            final color = confirmado ? const Color(0xFF15803D) : rechazado ? const Color(0xFFB91C1C) : const Color(0xFF92400E);
            final items = ((p['detalle'] as List?) ?? []).whereType<Map>();
            return Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Card(color: Colors.white, elevation: 1,
                  child: Padding(padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Icon(confirmado ? Icons.check_circle_outline : rechazado ? Icons.cancel_outlined : Icons.receipt_long_outlined, color: color, size: 54),
                      const SizedBox(height: 12),
                      const Text('ElectroHogar', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                      Text(confirmado ? 'Voucher de compra' : 'Constancia de pedido',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(estado, textAlign: TextAlign.center,
                        style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Divider(),
                      fila('Pedido', '#${p['id']}'),
                      if (p['venta_id'] != null) fila('Venta', '#${p['venta_id']}'),
                      fila('Cliente', (p['cliente'] ?? '').toString()),
                      fila('Fecha del pedido', (p['fecha'] ?? '').toString()),
                      fila('Método de pago', metodosPedido[p['metodo_pago'].toString()] ?? p['metodo_pago'].toString()),
                      if ((p['referencia'] ?? '').toString().isNotEmpty)
                        fila('Operación informada', p['referencia'].toString()),
                      if (confirmado && p['fecha_revision'] != null)
                        fila('Verificado el', p['fecha_revision'].toString()),
                      const Divider(),
                      const Text('Detalle de productos', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final it in items) Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((it['nombre'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Row(children: [
                            Expanded(child: Text('${it['cantidad']} × ${dineroPedido(it['precio_unitario'])}')),
                            Text(dineroPedido(it['subtotal'])),
                          ]),
                        ]),
                      ),
                      const Divider(),
                      Row(children: [
                        const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                        Text(dineroPedido(p['total']), style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 23)),
                      ]),
                      const SizedBox(height: 20),
                      Text(confirmado ? 'Gracias por tu compra.' : rechazado ? 'Este pedido no fue confirmado.' : 'El pedido fue registrado. Este documento no acredita un pago recibido.',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      const Text('Documento interno. No es una boleta o factura electrónica.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF667085), fontSize: 11)),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
              ]),
            ));
          },
        ),
      ),
    );
  }
}
