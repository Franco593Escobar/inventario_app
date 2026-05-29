import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/cierre_caja.dart';
import 'package:inventario_app/data/models/venta.dart';
import 'package:inventario_app/data/repositories/cierre_caja_repository.dart';
import 'package:inventario_app/data/repositories/venta_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

final _fmtMon = NumberFormat('\$#,##0.00', 'en_US');
final _fmtFechaCorta = DateFormat('dd/MM/yyyy HH:mm');

/// Denominaciones USD (Ecuador)
const _kDenominaciones = <(String, double)>[
  ('\$100', 100.0),
  ('\$50', 50.0),
  ('\$20', 20.0),
  ('\$10', 10.0),
  ('\$5', 5.0),
  ('\$2', 2.0),
  ('\$1', 1.0),
  ('\$0.50', 0.50),
  ('\$0.25', 0.25),
  ('\$0.10', 0.10),
  ('\$0.05', 0.05),
  ('\$0.01', 0.01),
];

class CierreCajaTab extends StatefulWidget {
  const CierreCajaTab({super.key});

  @override
  State<CierreCajaTab> createState() => _CierreCajaTabState();
}

class _CierreCajaTabState extends State<CierreCajaTab> {
  final _cierreRepo = CierreCajaRepository();
  final _ventaRepo = VentaRepository();
  final _fondoCtrl = TextEditingController(text: '0.00');
  final _obsCtrl = TextEditingController();

  // Conteo de denominaciones: clave = etiqueta ej '\$100'
  final Map<String, int> _conteo =
      Map.fromEntries(_kDenominaciones.map((d) => MapEntry(d.$1, 0)));

  bool _guardando = false;

  @override
  void dispose() {
    _fondoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  double get _fondoInicial =>
      double.tryParse(_fondoCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _efectivoContado =>
      _kDenominaciones.fold(0.0, (a, d) => a + ((_conteo[d.$1] ?? 0) * d.$2));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return StreamBuilder<List<Venta>>(
      stream: _ventaRepo.watchByTenant(auth.tenantId),
      builder: (context, snapVentas) {
        final todasVentas = snapVentas.data ?? [];
        final hoy = DateTime.now();
        final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
        final ventasHoy = todasVentas
            .where(
                (v) => v.estado == 'completada' && !v.fecha.isBefore(inicioHoy))
            .toList();

        final totalEfectivo = ventasHoy
            .where((v) => v.metodoPago == 'efectivo')
            .fold(0.0, (a, v) => a + v.total);
        final totalTarjeta = ventasHoy
            .where((v) => v.metodoPago == 'tarjeta')
            .fold(0.0, (a, v) => a + v.total);
        final totalTransferencia = ventasHoy
            .where((v) => v.metodoPago == 'transferencia')
            .fold(0.0, (a, v) => a + v.total);
        final totalOtros = ventasHoy
            .where((v) =>
                v.metodoPago != 'efectivo' &&
                v.metodoPago != 'tarjeta' &&
                v.metodoPago != 'transferencia')
            .fold(0.0, (a, v) => a + v.total);
        final totalVentas =
            totalEfectivo + totalTarjeta + totalTransferencia + totalOtros;

        final totalEsperado = _fondoInicial + totalEfectivo;
        final diferencia = _efectivoContado - totalEsperado;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna izquierda: formulario de cierre
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSeccionHeader(Icons.account_balance_wallet_outlined,
                        'Fondo Inicial de Caja'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _fondoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Fondo inicial (\$)',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSeccionHeader(
                        Icons.bar_chart_rounded, 'Ventas del Turno (Hoy)'),
                    const SizedBox(height: 12),
                    _buildResumenVentas(
                      totalVentas: totalVentas,
                      efectivo: totalEfectivo,
                      tarjeta: totalTarjeta,
                      transferencia: totalTransferencia,
                      otros: totalOtros,
                      nVentas: ventasHoy.length,
                    ),
                    const SizedBox(height: 24),
                    _buildSeccionHeader(Icons.calculate_outlined,
                        'Conteo de Billetes y Monedas'),
                    const SizedBox(height: 12),
                    _buildConteoTable(),
                    const SizedBox(height: 24),
                    _buildSeccionHeader(
                        Icons.summarize_outlined, 'Resumen de Cierre'),
                    const SizedBox(height: 12),
                    _buildResumenCierre(
                      fondoInicial: _fondoInicial,
                      totalEfectivo: totalEfectivo,
                      totalEsperado: totalEsperado,
                      efectivoContado: _efectivoContado,
                      diferencia: diferencia,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _guardando
                            ? null
                            : () => _cerrarCaja(
                                  context,
                                  auth,
                                  totalEfectivo: totalEfectivo,
                                  totalTarjeta: totalTarjeta,
                                  totalTransferencia: totalTransferencia,
                                  totalOtros: totalOtros,
                                  diferencia: diferencia,
                                  nVentas: ventasHoy.length,
                                ),
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.lock_outlined),
                        label:
                            Text(_guardando ? 'Guardando...' : 'Cerrar Caja'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Columna derecha: historial de cierres
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _buildHistorialCierres(auth.tenantId),
            ),
          ],
        );
      },
    );
  }

  // ─── Secciones ─────────────────────────────────────────────────────────

  Widget _buildSeccionHeader(IconData icon, String titulo) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary)),
      ],
    );
  }

  Widget _buildResumenVentas({
    required double totalVentas,
    required double efectivo,
    required double tarjeta,
    required double transferencia,
    required double otros,
    required int nVentas,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _FilaResumen(
              label: 'Total ventas del día',
              value: _fmtMon.format(totalVentas),
              bold: true),
          _FilaResumen(
              label: '$nVentas operaciones realizadas',
              value: '',
              color: Colors.grey.shade600),
          const Divider(height: 16),
          _FilaResumen(
              label: '💵 Efectivo',
              value: _fmtMon.format(efectivo),
              color: Colors.green.shade700),
          _FilaResumen(
              label: '💳 Tarjeta',
              value: _fmtMon.format(tarjeta),
              color: Colors.indigo),
          _FilaResumen(
              label: '🏦 Transferencia',
              value: _fmtMon.format(transferencia),
              color: Colors.teal),
          if (otros > 0)
            _FilaResumen(
                label: 'Otros',
                value: _fmtMon.format(otros),
                color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildConteoTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 2,
                    child: Text('Denominación',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                const Expanded(
                    flex: 2,
                    child: Text('Cantidad',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    flex: 2,
                    child: Text('Subtotal',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          ..._kDenominaciones.map((d) {
            final cantidad = _conteo[d.$1] ?? 0;
            final subtotal = cantidad * d.$2;
            return _DenominacionRow(
              etiqueta: d.$1,
              cantidad: cantidad,
              subtotal: subtotal,
              onChanged: (v) => setState(() => _conteo[d.$1] = v),
            );
          }),
          // Total contado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(top: BorderSide(color: Colors.green.shade200)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 4,
                    child: Text('TOTAL CONTADO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success))),
                Expanded(
                    flex: 2,
                    child: Text(_fmtMon.format(_efectivoContado),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.success))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCierre({
    required double fondoInicial,
    required double totalEfectivo,
    required double totalEsperado,
    required double efectivoContado,
    required double diferencia,
  }) {
    final sobrante = diferencia >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sobrante ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: sobrante ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Column(
        children: [
          _FilaResumen(
              label: 'Fondo inicial en caja',
              value: _fmtMon.format(fondoInicial)),
          _FilaResumen(
              label: 'Ventas cobradas en efectivo',
              value: _fmtMon.format(totalEfectivo),
              color: Colors.green.shade700),
          const Divider(height: 14),
          _FilaResumen(
              label: 'Total esperado en caja',
              value: _fmtMon.format(totalEsperado),
              bold: true),
          _FilaResumen(
              label: 'Total contado físicamente',
              value: _fmtMon.format(efectivoContado),
              bold: true),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sobrante ? '✓ Sobrante' : '⚠ Faltante',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: sobrante ? AppColors.success : AppColors.error)),
              Text(_fmtMon.format(diferencia.abs()),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: sobrante ? AppColors.success : AppColors.error)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Historial cierres ─────────────────────────────────────────────────

  Widget _buildHistorialCierres(String tenantId) {
    return StreamBuilder<List<CierreCaja>>(
      stream: _cierreRepo.watchByTenant(tenantId),
      builder: (context, snap) {
        final cierres = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Historial de Cierres',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary)),
                  const Spacer(),
                  Text('${cierres.length}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (cierres.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Sin cierres registrados',
                      style: TextStyle(color: Colors.grey.shade400)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: cierres.length,
                  itemBuilder: (_, i) => _CierreCard(cierre: cierres[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── Acción cerrar caja ────────────────────────────────────────────────

  Future<void> _cerrarCaja(
    BuildContext context,
    AuthProvider auth, {
    required double totalEfectivo,
    required double totalTarjeta,
    required double totalTransferencia,
    required double totalOtros,
    required double diferencia,
    required int nVentas,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Cierre de Caja'),
        content: Text('¿Deseas registrar el cierre de caja?\n\n'
            'Total contado: ${_fmtMon.format(_efectivoContado)}\n'
            'Diferencia: ${_fmtMon.format(diferencia)} '
            '(${diferencia >= 0 ? "sobrante" : "faltante"})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Caja'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _guardando = true);
    try {
      final ahora = DateTime.now();
      final cierre = CierreCaja(
        id: '',
        tenantId: auth.tenantId,
        operador: auth.loginUsername,
        fechaApertura: DateTime(ahora.year, ahora.month, ahora.day),
        fechaCierre: ahora,
        fondoInicial: _fondoInicial,
        totalEfectivo: totalEfectivo,
        totalTarjeta: totalTarjeta,
        totalTransferencia: totalTransferencia,
        totalOtros: totalOtros,
        efectivoContado: _efectivoContado,
        denominaciones: Map<String, int>.from(_conteo)
          ..removeWhere((_, v) => v == 0),
        diferencia: diferencia,
        cantidadVentas: nVentas,
        observaciones:
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );
      await _cierreRepo.guardar(cierre);

      // Resetear formulario
      if (mounted) {
        setState(() {
          _fondoCtrl.text = '0.00';
          _obsCtrl.clear();
          for (final k in _conteo.keys) {
            _conteo[k] = 0;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Cierre de caja registrado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────

class _FilaResumen extends StatelessWidget {
  const _FilaResumen(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});
  final String label, value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                      color: color ?? Colors.black87)),
            ),
            if (value.isNotEmpty)
              Text(value,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                      color: color ?? Colors.black87)),
          ],
        ),
      );
}

class _DenominacionRow extends StatefulWidget {
  const _DenominacionRow({
    required this.etiqueta,
    required this.cantidad,
    required this.subtotal,
    required this.onChanged,
  });
  final String etiqueta;
  final int cantidad;
  final double subtotal;
  final ValueChanged<int> onChanged;

  @override
  State<_DenominacionRow> createState() => _DenominacionRowState();
}

class _DenominacionRowState extends State<_DenominacionRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.cantidad == 0 ? '' : widget.cantidad.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(widget.etiqueta,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  hintText: '0',
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) {
                  final n = int.tryParse(v) ?? 0;
                  widget.onChanged(n);
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
                widget.subtotal == 0 ? '' : _fmtMon.format(widget.subtotal),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    color: widget.subtotal > 0
                        ? AppColors.success
                        : Colors.grey.shade400,
                    fontWeight: widget.subtotal > 0
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}

class _CierreCard extends StatelessWidget {
  const _CierreCard({required this.cierre});
  final CierreCaja cierre;

  @override
  Widget build(BuildContext context) {
    final sobrante = cierre.diferencia >= 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmtFechaCorta.format(cierre.fechaCierre),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        sobrante ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sobrante
                        ? '+${_fmtMon.format(cierre.diferencia)}'
                        : '-${_fmtMon.format(cierre.diferencia.abs())}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sobrante
                            ? Colors.green.shade700
                            : Colors.red.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${cierre.operador} · ${cierre.cantidadVentas} ventas · ${_fmtMon.format(cierre.totalVentas)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
