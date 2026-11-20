import 'package:flutter/material.dart';
import 'productos_crud.dart';
import 'pedidos_page.dart';

const _black = Color(0xFF101114);
const _red = Color(0xFFDC2626);
const _soft = Color(0xFFF5F6F8);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE7E9EE);

String _money(dynamic value) {
  final number = double.tryParse((value ?? 0).toString()) ?? 0;
  return 'S/ ' + number.toStringAsFixed(2);
}

int _number(dynamic value) => int.tryParse((value ?? 0).toString()) ?? 0;

String _s(dynamic value, [String fallback = '—']) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

class _Section {
  final String id;
  final String title;
  final IconData icon;
  const _Section(this.id, this.title, this.icon);
}

const _sections = <_Section>[
  _Section('resumen', 'Resumen general', Icons.dashboard_rounded),
  _Section('productos', 'Productos', Icons.inventory_2_outlined),
  _Section('categorias', 'Categorías', Icons.category_outlined),
  _Section('clientes', 'Clientes', Icons.groups_2_outlined),
  _Section('ventas', 'Ventas', Icons.shopping_cart_outlined),
  _Section('pedidos', 'Pedidos y pagos', Icons.payments_outlined),
  _Section('proveedores', 'Proveedores', Icons.local_shipping_outlined),
  _Section('stock', 'Alertas de stock', Icons.warning_amber_rounded),
  _Section('reportes', 'Reportes', Icons.bar_chart_rounded),
];

class ElectroDashboardPlus extends StatefulWidget {
  const ElectroDashboardPlus({
    super.key,
    required this.usuario,
    required this.loadDashboard,
    required this.loadProducts,
    required this.saveProduct,
    required this.deleteProduct,
    required this.loadModule,
    required this.createClient,
    required this.updateClient,
    required this.deleteClient,
    required this.createCategory,
    required this.updateCategory,
    required this.deleteCategory,
    required this.loadSale,
    required this.cargarPedidos,
    required this.revisarPedido,
    required this.logout,
  });

  final Map<String, dynamic> usuario;
  final Future<Map<String, dynamic>> Function() loadDashboard;
  final Future<List<dynamic>> Function() loadProducts;
  final Future<String> Function(Map<String, dynamic>, int?) saveProduct;
  final Future<String> Function(int) deleteProduct;
  final Future<List<dynamic>> Function(String endpoint) loadModule;
  final Future<void> Function(Map<String, dynamic> cliente) createClient;
  final Future<void> Function(int id, Map<String, dynamic> cliente) updateClient;
  final Future<void> Function(int id) deleteClient;
  final Future<void> Function(Map<String, dynamic> categoria) createCategory;
  final Future<void> Function(int id, Map<String, dynamic> categoria) updateCategory;
  final Future<void> Function(int id) deleteCategory;
  final Future<Map<String, dynamic>> Function(int id) loadSale;
  final CargarPedidos cargarPedidos;
  final RevisarPedido revisarPedido;
  final Future<void> Function() logout;

  @override
  State<ElectroDashboardPlus> createState() => _ElectroDashboardPlusState();
}

class _ElectroDashboardPlusState extends State<ElectroDashboardPlus> {
  String section = 'resumen';
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> products = [];
  int revision = 0;

  String get role => _s(widget.usuario['rol'], '');
  bool get staff => role == 'admin' || role == 'vendedor';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.loadDashboard();
      final prods = await widget.loadProducts();
      if (!mounted) return;
      setState(() {
        summary = data;
        products = prods.map((v) => Map<String, dynamic>.from(v as Map)).toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void select(String id, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.of(context).pop();
    setState(() {
      section = id;
      revision++;
    });
    if (id == 'resumen' || id == 'stock' || id == 'reportes') refresh();
  }

  Future<void> signOut() async {
    try {
      await widget.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: ' + e.toString())),
      );
    }
  }

  Widget sidebar({required bool drawer}) {
    final name = _s(widget.usuario['nombre'], 'Usuario');
    return Container(
      width: 266,
      color: _black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Image.asset(
                      'assets/logo-electrohogar.jpg',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.home_work, color: _red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ElectroHogar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text('VENTAS E INVENTARIO',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              letterSpacing: .8,
                              fontSize: 9,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF34353B)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3A2125),
                    foregroundColor: const Color(0xFFFFA0A0),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                        const SizedBox(height: 3),
                        Text(
                          'Rol: ' + role,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(23, 0, 0, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MENÚ PRINCIPAL',
                  style: TextStyle(
                    color: Color(0xFF7D828D),
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                children: [
                  for (final item in _sections)
                    if (staff ||
                        !{'clientes', 'ventas', 'proveedores', 'reportes', 'pedidos'}
                            .contains(item.id))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: section == item.id
                              ? const Color(0xFFAA1D24)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => select(item.id, closeDrawer: drawer),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Icon(item.icon,
                                      size: 19,
                                      color: section == item.id
                                          ? Colors.white
                                          : const Color(0xFFBDC1CA)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(item.title,
                                        style: TextStyle(
                                          color: section == item.id
                                              ? Colors.white
                                              : const Color(0xFFD1D5DB),
                                          fontSize: 13,
                                          fontWeight: section == item.id
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        )),
                                  ),
                                  if (item.id == 'stock' &&
                                      summary.isNotEmpty &&
                                      _number(summary['stock_bajo']) > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF642329),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        _number(summary['stock_bajo']).toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF34353B)),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: const Icon(Icons.logout, color: Color(0xFFFCA5A5)),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 13),
              ),
              onTap: signOut,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget heading(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171717),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget kpiCards() {
    final cards = [
      ('Productos activos', _number(summary['total_productos']).toString(),
          Icons.inventory_2_outlined, const Color(0xFF2563EB)),
      ('Fichas de clientes', _number(summary['total_clientes']).toString(),
          Icons.groups_2_outlined, const Color(0xFF7C3AED)),
      ('Cuentas cliente', _number(summary['cuentas_cliente']).toString(),
          Icons.person_outline, const Color(0xFF7C3AED)),
      ('Ventas totales', _number(summary['total_ventas']).toString(),
          Icons.shopping_cart_outlined, const Color(0xFF16A34A)),
      ('Ingresos acumulados', _money(summary['ingresos']),
          Icons.payments_outlined, const Color(0xFFDC2626)),
      ('Ventas de hoy', _number(summary['ventas_hoy']).toString(),
          Icons.today_outlined, const Color(0xFF16A34A)),
      ('Ingresos de hoy', _money(summary['ingresos_hoy']),
          Icons.account_balance_wallet_outlined, const Color(0xFFDC2626)),
      ('Stock bajo', _number(summary['stock_bajo']).toString(),
          Icons.warning_amber_rounded, const Color(0xFFEA580C)),
      ('Pedidos pendientes', _number(summary['pedidos_pendientes']).toString(),
          Icons.pending_actions_outlined, const Color(0xFFB45309)),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 860 ? 3 : box.maxWidth >= 320 ? 2 : 1;
        final width = (box.maxWidth - (columns - 1) * 13) / columns;
        return Wrap(
          spacing: 13,
          runSpacing: 13,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: Container(
                  height: 148,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: _line),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(card.$3, color: card.$4, size: 25),
                      const Spacer(),
                      Text(card.$1,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          card.$2,
                          style: const TextStyle(
                            color: _black,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget welcome() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF151515), Color(0xFF54151A), Color(0xFF941F26)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Wrap(
        runSpacing: 14,
        spacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PANEL DE ADMINISTRACIÓN',
                  style: TextStyle(
                    color: Color(0xFFFECACA),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Bienvenido, ' + _s(widget.usuario['nombre'], 'Usuario'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Toda la información de tu negocio en un solo lugar.',
                  style: TextStyle(color: Color(0xFFE6E6E6), fontSize: 13),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Actualizar datos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x77FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget avisosPedidos() {
    final pendientes = _number(summary['pedidos_pendientes']);
    if (pendientes == 0 || !staff) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFED7AA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.pending_actions_outlined,
            color: Color(0xFFB45309), size: 27),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pendientes == 1
                    ? '1 pedido pendiente de revisión'
                    : '$pendientes pedidos pendientes de revisión',
                style: const TextStyle(
                  color: Color(0xFF92400E), fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('Verifica el pago antes de registrar la venta.',
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Revisar pedidos y pagos',
          onPressed: () => select('pedidos'),
          icon: const Icon(Icons.arrow_forward, color: Color(0xFF92400E)),
        ),
      ]),
    );
  }

  Widget quickLinks() {
    final links = [
      ('Productos', Icons.inventory_2_outlined, 'productos'),
      if (staff) ('Clientes', Icons.groups_outlined, 'clientes'),
      if (staff) ('Ventas', Icons.shopping_bag_outlined, 'ventas'),
      if (staff) ('Pedidos y pagos', Icons.pending_actions_outlined, 'pedidos'),
      ('Stock bajo', Icons.warning_amber_outlined, 'stock'),
      if (staff) ('Reportes', Icons.bar_chart_outlined, 'reportes'),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final link in links)
          OutlinedButton.icon(
            onPressed: () => select(link.$3),
            icon: Icon(link.$2, size: 18),
            label: Text(link.$1),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _black,
              side: const BorderSide(color: _line),
              padding: const EdgeInsets.symmetric(
                horizontal: 15, vertical: 17,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(17),
      ),
      child: child,
    );
  }

  Widget latestSales() {
    final items = (summary['ultimas_ventas'] as List? ?? []).cast<dynamic>();
    return panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Últimas ventas', subtitle: 'Movimientos recientes registrados'),
          if (items.isEmpty)
            const Text('Todavía no hay ventas registradas.',
                style: TextStyle(color: _muted))
          else
            for (final raw in items.take(5))
              Builder(builder: (context) {
                final sale = Map<String, dynamic>.from(raw as Map);
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFEE2E2),
                        child: Icon(Icons.receipt_long_outlined, color: _red),
                      ),
                      title: Text(
                        'Venta #' + _s(sale['id']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(_s(sale['cliente'], 'Sin cliente') +
                          ' · ' + _s(sale['fecha'])),
                      trailing: Text(
                        _money(sale['total']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: staff
                          ? () => saleDetails(_number(sale['id']))
                          : null,
                    ),
                    const Divider(height: 1, color: _line),
                  ],
                );
              }),
          if (staff)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => select('ventas'),
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('Ver todas las ventas'),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get lowStock => products.where((p) {
    final active = _number(p['estado']) == 1;
    return active && _number(p['stock']) <= _number(p['stock_minimo']);
  }).toList()..sort(
      (a, b) => _number(a['stock']).compareTo(_number(b['stock'])),
    );

  Widget stockPanel({bool all = false}) {
    final items = lowStock;
    return panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            'Alertas de stock',
            subtitle: 'Productos que necesitan reposición',
          ),
          if (items.isEmpty)
            const Text('No hay productos con stock bajo.',
                style: TextStyle(color: _muted))
          else
            for (final p in (all ? items : items.take(5)))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF4E6),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEA580C)),
                ),
                title: Text(_s(p['nombre']),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Mínimo: ' +
                    _number(p['stock_minimo']).toString() + ' unidades'),
                trailing: Text(
                  _number(p['stock']).toString() + ' und.',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: _red),
                ),
              ),
          if (!all)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => select('stock'),
                child: const Text('Revisar inventario'),
              ),
            ),
        ],
      ),
    );
  }

  Widget chartMonths() {
    final raw = (summary['ventas_meses'] as List? ?? []);
    if (raw.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Aún no hay datos mensuales para mostrar.',
            style: TextStyle(color: _muted)),
      );
    }
    final months = raw.map((v) => Map<String, dynamic>.from(v as Map)).toList();
    final maxValue = months
        .map((m) => double.tryParse((m['ingresos'] ?? 0).toString()) ?? 0)
        .fold<double>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Tooltip(
                  message: _s(m['mes']) + ': ' + _money(m['ingresos']),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _money(m['ingresos']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: _muted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12.0 +
                            145.0 *
                                ((double.tryParse((m['ingresos'] ?? 0).toString()) ??
                                        0) /
                                    maxValue),
                        decoration: const BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_s(m['mes']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 10, color: _muted)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget reports() {
    final payments = (summary['metodos_pago'] as List? ?? []);
    final top = (summary['top_productos'] as List? ?? []);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        heading('Reportes de ventas',
            subtitle: 'Indicadores calculados desde MySQL'),
        LayoutBuilder(
          builder: (context, size) {
            final wide = size.maxWidth >= 780;
            final left = panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Ingresos por mes',
                      subtitle: 'Evolución de los últimos meses'),
                  chartMonths(),
                ],
              ),
            );
            final right = panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Resumen de este mes'),
                  _reportMetric('Ventas del mes', summary['ventas_mes'].toString()),
                  const SizedBox(height: 15),
                  _reportMetric('Ingresos del mes', _money(summary['ingresos_mes'])),
                  const Divider(height: 32),
                  heading('Métodos de pago'),
                  if (payments.isEmpty)
                    const Text('Sin registros',
                        style: TextStyle(color: _muted)),
                  for (final item in payments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_s((item as Map)['metodo'])),
                      trailing: Text(_s(item['cantidad'])),
                    ),
                ],
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: left),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: right),
                    ],
                  )
                : Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
        const SizedBox(height: 17),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Productos más vendidos',
                  subtitle: 'Unidades vendidas por producto'),
              if (top.isEmpty)
                const Text('Todavía no hay información.',
                    style: TextStyle(color: _muted)),
              for (final item in top)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.workspace_premium_outlined,
                      color: _red),
                  title: Text(_s((item as Map)['nombre'])),
                  trailing: Text(_s(item['unidades']) + ' und.'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
            )),
      ],
    );
  }

  Widget overview() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        welcome(),
        const SizedBox(height: 22),
        if (loading)
          const LinearProgressIndicator()
        else if (error != null)
          _ErrorPanel(error: error!, retry: refresh)
        else ...[
          kpiCards(),
          if (_number(summary['pedidos_pendientes']) > 0) ...[
            const SizedBox(height: 18),
            avisosPedidos(),
          ],
          const SizedBox(height: 28),
          heading('Accesos rápidos',
              subtitle: 'Consulta los módulos principales del sistema'),
          quickLinks(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, size) {
              final wide = size.maxWidth >= 850;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: latestSales()),
                        const SizedBox(width: 17),
                        Expanded(flex: 2, child: stockPanel()),
                      ],
                    )
                  : Column(
                      children: [
                        latestSales(),
                        const SizedBox(height: 16),
                        stockPanel(),
                      ],
                    );
            },
          ),
          const SizedBox(height: 21),
          if (staff)
            panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Ingresos mensuales'),
                  chartMonths(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => select('reportes'),
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Ver reportes'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget listModule() {
    final id = section;
    if (id == 'productos') {
      return ProductosCrudPage(
        key: ValueKey('productos-' + revision.toString()),
        puedeEditar: role == 'admin',
        cargarProductos: widget.loadProducts,
        cargarCategorias: () => widget.loadModule('categorias.php'),
        guardar: widget.saveProduct,
        eliminar: widget.deleteProduct,
        actualizarResumen: () { refresh(); },
      );
    }
    if (id == 'categorias') {
      return _CollectionPage(
        key: ValueKey('categorias-' + revision.toString()),
        title: 'Categorías',
        subtitle: 'Clasifica los productos de ElectroHogar',
        icon: Icons.category_outlined,
        load: () => widget.loadModule('categorias.php'),
        titleFor: (m) => _s(m['nombre']),
        detailFor: (m) => _s(m['descripcion'], 'Sin descripción'),
        valueFor: (m) => 'Productos: ${_number(m['total_productos'])}',
        addLabel: 'Nueva categoría',
        onAdd: role == 'admin' ? () => categoryForm() : null,
        onTap: role == 'admin' ? categoryForm : null,
        onEdit: role == 'admin' ? categoryForm : null,
        onDelete: role == 'admin' ? deleteCategory : null,
      );
    }
    if (id == 'clientes') {
      return _CollectionPage(
        key: ValueKey('clientes-' + revision.toString()),
        title: 'Clientes',
        subtitle: 'Registra, busca y administra las fichas de clientes',
        icon: Icons.groups_outlined,
        load: () => widget.loadModule('clientes.php'),
        titleFor: (m) => _s(m['nombres']) + ' ' + _s(m['apellidos'], ''),
        detailFor: (m) => 'DNI: ' + _s(m['dni']) +
            ' · Tel: ' + _s(m['telefono']) +
            ' · Correo: ' + _s(m['email'], 'Sin correo'),
        valueFor: (m) => _s(m['direccion'], ''),
        onAdd: () => clientForm(),
        onTap: clientForm,
        onEdit: clientForm,
        onDelete: role == 'admin' ? deleteClient : null,
      );
    }
    if (id == 'pedidos' && staff) {
      return HistorialPedidosPage(
        key: ValueKey('pedidos-' + revision.toString()),
        cargar: widget.cargarPedidos,
        revisar: widget.revisarPedido,
        alCambiar: () { refresh(); },
      );
    }
    if (id == 'ventas') {
      return _CollectionPage(
        key: ValueKey('ventas-' + revision.toString()),
        title: 'Ventas',
        subtitle: 'Historial de transacciones realizadas',
        icon: Icons.receipt_long_outlined,
        load: () => widget.loadModule('ventas.php'),
        titleFor: (m) => 'Venta #' + _s(m['id']),
        detailFor: (m) => _s(m['cliente']) +
            ' · ' + _s(m['fecha']) + ' · ' + _s(m['metodo_pago']),
        valueFor: (m) => _money(m['total']),
        onTap: (m) => saleDetails(_number(m['id'])),
      );
    }
    return _CollectionPage(
      key: ValueKey('proveedores-' + revision.toString()),
      title: 'Proveedores',
      subtitle: 'Directorio de proveedores',
      icon: Icons.local_shipping_outlined,
      load: () => widget.loadModule('proveedores.php'),
      titleFor: (m) => _s(m['razon_social']),
      detailFor: (m) => 'RUC: ' + _s(m['ruc']) +
          ' · Tel: ' + _s(m['telefono']),
      valueFor: (m) => _s(m['contacto'], ''),
    );
  }

  Future<void> saleDetails(int id) async {
    if (id <= 0) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Detalle de venta #' + id.toString()),
        content: SizedBox(
          width: 470,
          child: FutureBuilder<Map<String, dynamic>>(
            future: widget.loadSale(id),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text('No se pudo consultar: ' + snap.error.toString());
              }
              final data = snap.data ?? {};
              final detail = (data['detalle'] as List? ?? []);
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: ' + _s(data['cliente'])),
                    Text('Total: ' + _money(data['total'])),
                    Text('Método de pago: ' + _s(data['metodo_pago'])),
                    const Divider(height: 25),
                    for (final item in detail)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_s((item as Map)['producto'])),
                        subtitle: Text('Cantidad: ' + _s(item['cantidad'])),
                        trailing: Text(_money(item['subtotal'])),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Formulario para registrar o actualizar categorías.
  Future<void> categoryForm([Map<String, dynamic>? categoria]) async {
    if (role != 'admin') return;
    final editing = categoria != null;
    final id = _number(categoria?['id']);
    if (editing && id <= 0) return;
    final formKey = GlobalKey<FormState>();
    final nombre = TextEditingController(text: _s(categoria?['nombre'], ''));
    final descripcion = TextEditingController(
        text: _s(categoria?['descripcion'], ''));

    try {
      final aceptado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(editing ? 'Editar categoría' : 'Nueva categoría'),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombre,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la categoría *',
                        hintText: 'Ej.: Refrigeradoras',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      validator: (v) {
                        final valor = (v ?? '').trim();
                        if (valor.isEmpty) return 'Escribe un nombre';
                        if (valor.length > 100) {
                          return 'Máximo 100 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descripcion,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Productos que pertenecen a la categoría',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      validator: (v) => (v ?? '').trim().length > 255
                          ? 'Máximo 255 caracteres'
                          : null,
                    ),
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
              icon: Icon(editing ? Icons.save_outlined : Icons.add),
              label: Text(editing ? 'Guardar cambios' : 'Crear categoría'),
            ),
          ],
        ),
      );
      if (aceptado != true) return;

      final datos = <String, dynamic>{
        'nombre': nombre.text.trim(),
        'descripcion': descripcion.text.trim(),
      };
      if (editing) {
        await widget.updateCategory(id, datos);
      } else {
        await widget.createCategory(datos);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(editing
            ? 'Categoría actualizada correctamente.'
            : 'Categoría registrada correctamente.'),
      ));
      setState(() => revision++);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo guardar: '
            + e.toString().replaceFirst('Exception: ', '')),
      ));
    } finally {
      nombre.dispose();
      descripcion.dispose();
    }
  }

  Future<void> deleteCategory(Map<String, dynamic> categoria) async {
    if (role != 'admin') return;
    final id = _number(categoria['id']);
    if (id <= 0) return;
    final cantidad = _number(categoria['total_productos']);
    if (cantidad > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No puedes eliminar esta categoría: tiene '
            '$cantidad productos asociados. Reasigna primero esos productos.'),
      ));
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text('Se eliminará "${_s(categoria['nombre'])}". '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar categoría'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await widget.deleteCategory(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Categoría eliminada correctamente.'),
      ));
      setState(() => revision++);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo eliminar: '
            + e.toString().replaceFirst('Exception: ', '')),
      ));
    }
  }

  Future<void> clientForm([Map<String, dynamic>? cliente]) async {
    final editing = cliente != null;
    final id = _number(cliente?['id']);
    if (editing && id <= 0) return;
    final formKey = GlobalKey<FormState>();
    final names = TextEditingController(text: _s(cliente?['nombres'], ''));
    final surnames = TextEditingController(text: _s(cliente?['apellidos'], ''));
    final dni = TextEditingController(text: _s(cliente?['dni'], ''));
    final phone = TextEditingController(text: _s(cliente?['telefono'], ''));
    final email = TextEditingController(text: _s(cliente?['email'], ''));
    final address = TextEditingController(text: _s(cliente?['direccion'], ''));

    String? validarLargo(String? texto, String campo, int max) {
      if ((texto ?? '').trim().length > max) {
        return '$campo permite hasta $max caracteres';
      }
      return null;
    }

    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(editing ? 'Editar cliente' : 'Registrar nuevo cliente'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: names,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nombres *'),
                      validator: (v) {
                        final valor = (v ?? '').trim();
                        if (valor.isEmpty) return 'Ingresa los nombres';
                        if (valor.length > 100) return 'Máximo 100 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: surnames,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                      validator: (v) => validarLargo(v, 'Apellidos', 100),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dni,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'DNI (8 dígitos)'),
                      validator: (v) {
                        final valor = (v ?? '').trim();
                        if (valor.isEmpty || RegExp(r'^[0-9]{8}$').hasMatch(valor)) {
                          return null;
                        }
                        return 'El DNI debe tener 8 dígitos';
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      validator: (v) => validarLargo(v, 'Teléfono', 20),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo electrónico'),
                      validator: (v) {
                        final valor = (v ?? '').trim();
                        if (valor.isEmpty) return null;
                        if (valor.length > 120) return 'Máximo 120 caracteres';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(valor)) {
                          return 'Escribe un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: address,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Dirección'),
                      validator: (v) => validarLargo(v, 'Dirección', 200),
                    ),
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
              icon: Icon(editing ? Icons.save_outlined : Icons.person_add_alt_1),
              label: Text(editing ? 'Guardar cambios' : 'Registrar cliente'),
            ),
          ],
        ),
      );
      if (accepted != true) return;

      final datos = <String, dynamic>{
        'nombres': names.text.trim(),
        'apellidos': surnames.text.trim(),
        'dni': dni.text.trim().isEmpty ? null : dni.text.trim(),
        'telefono': phone.text.trim(),
        'email': email.text.trim(),
        'direccion': address.text.trim(),
      };
      if (editing) {
        await widget.updateClient(id, datos);
      } else {
        await widget.createClient(datos);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(editing
            ? 'Cliente actualizado correctamente.'
            : 'Cliente registrado correctamente.')),
      );
      setState(() => revision++);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: '
            + e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      names.dispose();
      surnames.dispose();
      dni.dispose();
      phone.dispose();
      email.dispose();
      address.dispose();
    }
  }

  Future<void> deleteClient(Map<String, dynamic> cliente) async {
    if (role != 'admin') return;
    final id = _number(cliente['id']);
    if (id <= 0) return;
    final nombre = ('${_s(cliente['nombres'])} '
        '${_s(cliente['apellidos'], '')}').trim();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar cliente?'),
        content: Text('Se eliminará la ficha de "$nombre". '
            'Esta acción no se puede deshacer. '
            'Si el cliente tiene ventas registradas, el sistema impedirá eliminarlo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar cliente'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await widget.deleteClient(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente eliminado correctamente.')),
      );
      setState(() => revision++);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: '
            + e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget mainContent() {
    if (section == 'resumen') return overview();
    if (section == 'stock') {
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null) _ErrorPanel(error: error!, retry: refresh),
          stockPanel(all: true),
        ],
      );
    }
    if (section == 'reportes') {
      if (loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (error != null) {
        return _ErrorPanel(error: error!, retry: refresh);
      }
      return reports();
    }
    return listModule();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final desktop = screenWidth >= 950;
    final title = _sections
        .firstWhere((item) => item.id == section)
        .title;
    return Scaffold(
      backgroundColor: _soft,
      drawer: desktop
          ? null
          : Drawer(
              width: 266,
              backgroundColor: _black,
              child: sidebar(drawer: true),
            ),
      appBar: desktop
          ? null
          : AppBar(
              title: Text(title),
              actions: [
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: Row(
        children: [
          if (desktop) sidebar(drawer: false),
          Expanded(
            child: Column(
              children: [
                if (desktop)
                  Container(
                    height: 75,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: _line),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            color: _black,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.circle, color: Color(0xFF16A34A), size: 9),
                        const SizedBox(width: 8),
                        const Text('Sistema conectado',
                            style: TextStyle(
                                color: _muted, fontSize: 12)),
                        const SizedBox(width: 16),
                        IconButton(
                          tooltip: 'Actualizar datos',
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: mainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.retry});

  final String error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF1F2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: const TextStyle(color: Color(0xFF991B1B))),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: retry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionPage extends StatefulWidget {
  const _CollectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.load,
    required this.titleFor,
    required this.detailFor,
    required this.valueFor,
    this.onAdd,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.addLabel = 'Nuevo cliente',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Future<List<dynamic>> Function() load;
  final String Function(Map<String, dynamic>) titleFor;
  final String Function(Map<String, dynamic>) detailFor;
  final String Function(Map<String, dynamic>) valueFor;
  final Future<void> Function()? onAdd;
  final Future<void> Function(Map<String, dynamic>)? onTap;
  final Future<void> Function(Map<String, dynamic>)? onEdit;
  final Future<void> Function(Map<String, dynamic>)? onDelete;
  final String addLabel;

  @override
  State<_CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<_CollectionPage> {
  bool loading = true;
  String? error;
  String query = '';
  List<Map<String, dynamic>> rows = [];
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.load();
      if (!mounted) return;
      setState(() {
        rows = result.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = rows.where((m) {
      final value = (widget.titleFor(m) + ' ' +
              widget.detailFor(m) + ' ' + widget.valueFor(m))
          .toLowerCase();
      return value.contains(query.toLowerCase().trim());
    }).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 24, color: _black, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(widget.subtitle,
              style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    final search = TextField(
                      controller: searchCtrl,
                      onChanged: (text) => setState(() => query = text),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar en el listado...',
                      ),
                    );
                    final add = widget.onAdd == null
                        ? const SizedBox.shrink()
                        : FilledButton.icon(
                            onPressed: widget.onAdd,
                            icon: const Icon(Icons.add),
                            label: Text(widget.addLabel),
                          );
                    return box.maxWidth >= 580
                        ? Row(
                            children: [
                              Expanded(child: search),
                              const SizedBox(width: 12),
                              add,
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              search,
                              if (widget.onAdd != null) ...[
                                const SizedBox(height: 10),
                                add,
                              ],
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                if (loading)
                  const LinearProgressIndicator()
                else if (error != null)
                  _ErrorPanel(error: error!, retry: load)
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('No se encontraron registros.',
                        style: TextStyle(color: _muted)),
                  )
                else
                  for (final item in filtered)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: _line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFEE2E2),
                          child: Icon(widget.icon, color: _red, size: 20),
                        ),
                        title: Text(
                          widget.titleFor(item),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(widget.detailFor(item)),
                        trailing: widget.onEdit != null || widget.onDelete != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.onEdit != null)
                                    IconButton(
                                      tooltip: 'Editar cliente',
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Color(0xFF2563EB)),
                                      onPressed: () => widget.onEdit!(item),
                                    ),
                                  if (widget.onDelete != null)
                                    IconButton(
                                      tooltip: 'Eliminar cliente',
                                      icon: const Icon(Icons.delete_outline,
                                          color: Color(0xFFDC2626)),
                                      onPressed: () => widget.onDelete!(item),
                                    ),
                                ],
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Text(
                                  widget.valueFor(item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _black,
                                  ),
                                ),
                              ),
                        onTap: widget.onTap == null
                            ? null
                            : () => widget.onTap!(item),
                      ),
                    ),
                if (!loading && error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Mostrando ' + filtered.length.toString() +
                            ' de ' + rows.length.toString() + ' registros',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
