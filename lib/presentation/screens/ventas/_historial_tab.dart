import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/venta.dart';
import 'package:inventario_app/data/repositories/venta_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

final _fmtMon = NumberFormat('\$#,##0.00', 'en_US');
final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
final _fmtDia = DateFormat('yyyy-MM-dd');

class HistorialTab extends StatefulWidget {
  const HistorialTab({super.key});

  @override
  State<HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends State<HistorialTab> {
  final _ventaRepo = VentaRepository();
  String? _tenantIdForStream;
  Stream<List<Venta>>? _ventasStream;

  // Filtros
  String _filtro = 'hoy'; // 'hoy' | 'semana' | 'mes' | 'todos'
  String _busqueda = '';
  final _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _busquedaCtrl.addListener(() =>
        setState(() => _busqueda = _busquedaCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  bool _dentroFiltro(Venta v) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    switch (_filtro) {
      case 'hoy':
        return !v.fecha.isBefore(hoy);
      case 'semana':
        return !v.fecha.isBefore(hoy.subtract(const Duration(days: 7)));
      case 'mes':
        return !v.fecha.isBefore(DateTime(ahora.year, ahora.month, 1));
      default:
        return true;
    }
  }

  void _ensureTenantStream(String tenantId) {
    if (_tenantIdForStream == tenantId && _ventasStream != null) return;
    _tenantIdForStream = tenantId;
    _ventasStream = _ventaRepo.watchByTenant(tenantId);
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = context.select<AuthProvider, String>((a) => a.tenantId);
    _ensureTenantStream(tenantId);
    final ventasStream = _ventasStream;
    if (ventasStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Venta>>(
      stream: ventasStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final todas = snap.data ?? [];
        final filtradas = todas
            .where((v) => v.estado != 'anulada' || _busqueda.isNotEmpty)
            .where(_dentroFiltro)
            .where((v) {
          if (_busqueda.isEmpty) return true;
          return v.id.toLowerCase().contains(_busqueda) ||
              v.vendedor.toLowerCase().contains(_busqueda) ||
              v.metodoPago.toLowerCase().contains(_busqueda) ||
              v.items.any((i) => i.nombre.toLowerCase().contains(_busqueda));
        }).toList();

        // Métricas
        final ventas =
            filtradas.where((v) => v.estado == 'completada').toList();
        final totalPeriodo = ventas.fold(0.0, (a, v) => a + v.total);
        final totalEfectivo = ventas
            .where((v) => v.metodoPago == 'efectivo')
            .fold(0.0, (a, v) => a + v.total);
        final totalTarjeta = ventas
            .where((v) => v.metodoPago == 'tarjeta')
            .fold(0.0, (a, v) => a + v.total);
        final totalTransferencia = ventas
            .where((v) => v.metodoPago == 'transferencia')
            .fold(0.0, (a, v) => a + v.total);

        return Column(
          children: [
            // Toolbar con filtros
            _buildToolbar(),
            // Métricas
            _buildMetricas(
              total: totalPeriodo,
              nVentas: ventas.length,
              efectivo: totalEfectivo,
              tarjeta: totalTarjeta,
              transferencia: totalTransferencia,
            ),
            // Lista
            Expanded(
              child: filtradas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No hay ventas en este período',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtradas.length,
                      itemBuilder: (_, i) => _VentaCard(venta: filtradas[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por producto, vendedor...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() => _busqueda = '');
                        })
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: Colors.grey.shade50,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filtro,
              isDense: true,
              borderRadius: BorderRadius.circular(8),
              items: const [
                DropdownMenuItem(value: 'hoy', child: Text('Hoy')),
                DropdownMenuItem(value: 'semana', child: Text('7 días')),
                DropdownMenuItem(value: 'mes', child: Text('Este mes')),
                DropdownMenuItem(value: 'todos', child: Text('Todo')),
              ],
              onChanged: (v) => setState(() => _filtro = v!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricas({
    required double total,
    required int nVentas,
    required double efectivo,
    required double tarjeta,
    required double transferencia,
  }) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: _MetricaTile(
                  label: 'Total período',
                  value: _fmtMon.format(total),
                  icon: Icons.monetization_on_outlined)),
          _Divider(),
          Expanded(
              child: _MetricaTile(
                  label: 'Ventas',
                  value: '$nVentas',
                  icon: Icons.receipt_outlined)),
          _Divider(),
          Expanded(
              child: _MetricaTile(
                  label: 'Efectivo',
                  value: _fmtMon.format(efectivo),
                  icon: Icons.payments_outlined)),
          _Divider(),
          Expanded(
              child: _MetricaTile(
                  label: 'Tarjeta',
                  value: _fmtMon.format(tarjeta + transferencia),
                  icon: Icons.credit_card)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2));
}

class _MetricaTile extends StatelessWidget {
  const _MetricaTile(
      {required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }
}

class _VentaCard extends StatefulWidget {
  const _VentaCard({required this.venta});
  final Venta venta;

  @override
  State<_VentaCard> createState() => _VentaCardState();
}

class _VentaCardState extends State<_VentaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.venta;
    final anulada = v.estado == 'anulada';
    final (metodoBg, metodoIcon) = _coloresMetodo(v.metodoPago);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: anulada ? Colors.grey.shade100 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: metodoBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(metodoIcon, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                            v.metodoPago[0].toUpperCase() +
                                v.metodoPago.substring(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fmtFecha.format(v.fecha),
                            style: const TextStyle(fontSize: 12)),
                        Text('${v.items.length} ítems · ${v.vendedor}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmtMon.format(v.total),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: anulada ? Colors.grey : AppColors.primary,
                              decoration:
                                  anulada ? TextDecoration.lineThrough : null)),
                      if (anulada)
                        const Text('ANULADA',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...v.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                              '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(2)}x ',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
                          Expanded(
                              child: Text(item.nombre,
                                  style: const TextStyle(fontSize: 12))),
                          Text(_fmtMon.format(item.subtotal),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    )),
                if (v.observaciones?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Obs: ${v.observaciones}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static (Color, IconData) _coloresMetodo(String metodo) => switch (metodo) {
        'tarjeta' => (Colors.indigo, Icons.credit_card),
        'transferencia' => (Colors.teal, Icons.account_balance_outlined),
        _ => (AppColors.success, Icons.payments_outlined),
      };
}
