import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/models/venta.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/data/repositories/venta_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final VentaRepository _ventaRepo = VentaRepository();
  final ProductRepository _productRepo = ProductRepository();
  String? _tenantIdForStreams;
  Stream<List<Venta>>? _ventasStream;
  Stream<List<Product>>? _productosStream;

  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _desde : _hasta,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (esDesde) {
          _desde = picked;
        } else {
          _hasta = picked;
        }
      });
    }
  }

  void _ensureTenantStreams(String tenantId) {
    if (_tenantIdForStreams == tenantId &&
        _ventasStream != null &&
        _productosStream != null) {
      return;
    }

    _tenantIdForStreams = tenantId;
    _ventasStream = _ventaRepo.watchByTenant(tenantId);
    _productosStream = _productRepo.watchByTenant(tenantId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenantId = auth.tenantId;
    final fmtDate = DateFormat('dd/MM/yyyy');
    _ensureTenantStreams(tenantId);
    final ventasStream = _ventasStream;
    final productosStream = _productosStream;
    if (ventasStream == null || productosStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Reportes'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Ventas'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ── Tab 0: Reporte de Ventas ───────────────────────────────────
          StreamBuilder<List<Venta>>(
            stream: ventasStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final todas = snap.data ?? [];
              // Filtrar por rango de fechas
              final desdeInicio =
                  DateTime(_desde.year, _desde.month, _desde.day);
              final hastaFin =
                  DateTime(_hasta.year, _hasta.month, _hasta.day, 23, 59, 59);
              final ventas = todas
                  .where((v) =>
                      v.estado == 'completada' &&
                      v.fecha.isAfter(
                          desdeInicio.subtract(const Duration(seconds: 1))) &&
                      v.fecha
                          .isBefore(hastaFin.add(const Duration(seconds: 1))))
                  .toList();

              final totalVentas = ventas.fold(0.0, (a, v) => a + v.total);
              final ticketPromedio =
                  ventas.isEmpty ? 0.0 : totalVentas / ventas.length;

              // Top productos
              final Map<String, _TopProducto> topMap = {};
              for (final v in ventas) {
                for (final item in v.items) {
                  if (topMap.containsKey(item.productoId)) {
                    topMap[item.productoId] = topMap[item.productoId]!
                        .sumar(item.cantidad, item.subtotal);
                  } else {
                    topMap[item.productoId] = _TopProducto(
                      nombre: item.nombre,
                      cantidad: item.cantidad,
                      total: item.subtotal,
                    );
                  }
                }
              }
              final top = topMap.values.toList()
                ..sort((a, b) => b.total.compareTo(a.total));

              // Ventas por día
              final Map<String, double> porDia = {};
              for (final v in ventas) {
                final key = DateFormat('dd/MM').format(v.fecha);
                porDia[key] = (porDia[key] ?? 0) + v.total;
              }

              return CustomScrollView(
                slivers: [
                  // Filtro de fechas
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_outlined,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text('Desde:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: Text(fmtDate.format(_desde)),
                            onPressed: () => _seleccionarFecha(true),
                          ),
                          const SizedBox(width: 12),
                          const Text('Hasta:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: Text(fmtDate.format(_hasta)),
                            onPressed: () => _seleccionarFecha(false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),

                  // Métricas
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ReporteCard(
                            icon: Icons.point_of_sale_outlined,
                            titulo: 'Total vendido',
                            valor: '\$${totalVentas.toStringAsFixed(2)}',
                            color: AppColors.success,
                          ),
                          _ReporteCard(
                            icon: Icons.receipt_long_outlined,
                            titulo: 'N° operaciones',
                            valor: ventas.length.toString(),
                            color: AppColors.primary,
                          ),
                          _ReporteCard(
                            icon: Icons.analytics_outlined,
                            titulo: 'Ticket promedio',
                            valor: '\$${ticketPromedio.toStringAsFixed(2)}',
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top productos
                  if (top.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text('Productos más vendidos',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _TopRow(rank: i + 1, item: top[i]),
                        childCount: top.length > 10 ? 10 : top.length,
                      ),
                    ),
                  ],

                  // Ventas por día
                  if (porDia.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Ventas por día',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: porDia.entries
                                .toList()
                                .reversed
                                .map((e) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 16),
                                      title: Text(e.key),
                                      trailing: Text(
                                        '\$${e.value.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (ventas.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('Sin ventas en el período seleccionado',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              );
            },
          ),

          // ── Tab 1: Reporte de Stock ────────────────────────────────────
          StreamBuilder<List<Product>>(
            stream: productosStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final productos = snap.data ?? [];
              final activos = productos.where((p) => p.activo).toList();
              final totalUnidades = activos.fold(0, (a, p) => a + p.stock);
              final valorStock =
                  activos.fold(0.0, (a, p) => a + (p.stock * p.costo));
              final agotados = activos.where((p) => p.stock <= 0).length;
              final bajos = activos
                  .where((p) => p.stock > 0 && p.stock <= p.stockMinimo)
                  .length;

              return CustomScrollView(
                slivers: [
                  // Métricas
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ReporteCard(
                            icon: Icons.inventory_2_outlined,
                            titulo: 'Total productos',
                            valor: activos.length.toString(),
                            color: AppColors.primary,
                          ),
                          _ReporteCard(
                            icon: Icons.stacked_bar_chart,
                            titulo: 'Unidades en stock',
                            valor: totalUnidades.toString(),
                            color: Colors.teal,
                          ),
                          _ReporteCard(
                            icon: Icons.attach_money,
                            titulo: 'Valor del inventario',
                            valor: '\$${valorStock.toStringAsFixed(2)}',
                            color: AppColors.success,
                          ),
                          _ReporteCard(
                            icon: Icons.warning_amber_outlined,
                            titulo: 'Alertas (bajo+agotado)',
                            valor: '${bajos + agotados}',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Inventario completo',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final p = activos[i];
                        final agotado = p.stock <= 0;
                        final bajo = !agotado && p.stock <= p.stockMinimo;
                        final color = agotado
                            ? Colors.red
                            : (bajo ? Colors.orange : AppColors.success);
                        return Card(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            dense: true,
                            title: Text(p.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(p.seccionNombre ?? '—',
                                style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${p.stock} uds',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                                Text(
                                    '\$${(p.stock * p.costo).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: activos.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelos de apoyo
// ─────────────────────────────────────────────────────────────────────────────

class _TopProducto {
  _TopProducto(
      {required this.nombre, required this.cantidad, required this.total});

  final String nombre;
  final double cantidad;
  final double total;

  _TopProducto sumar(double c, double t) =>
      _TopProducto(nombre: nombre, cantidad: cantidad + c, total: total + t);
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de apoyo
// ─────────────────────────────────────────────────────────────────────────────

class _ReporteCard extends StatelessWidget {
  const _ReporteCard({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  final IconData icon;
  final String titulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(valor,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(titulo,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.rank, required this.item});

  final int rank;
  final _TopProducto item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              rank <= 3 ? Colors.amber.shade100 : Colors.grey.shade100,
          child: Text('$rank',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3
                      ? Colors.amber.shade800
                      : Colors.grey.shade600)),
        ),
        title: Text(item.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(2)} unidades vendidas'),
        trailing: Text('\$${item.total.toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.success)),
      ),
    );
  }
}
