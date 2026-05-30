import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/cliente.dart';
import 'package:inventario_app/data/models/orden.dart';
import 'package:inventario_app/data/repositories/cliente_repository.dart';
import 'package:inventario_app/data/repositories/orden_repository.dart';

final _fmt = NumberFormat('\$#,##0.00', 'en_US');

enum _TipoFactura { consumidorFinal, electronica }

enum _MetodoPago { efectivo, tarjeta, transferencia, mixto }

/// Pantalla de cobro con selección de método de pago, cliente y tipo de factura.
/// Retorna `true` al Navigator si el pago fue exitoso.
class CobrarScreen extends StatefulWidget {
  const CobrarScreen({
    super.key,
    required this.orden,
    required this.tenantId,
    required this.vendedor,
    required this.ordenRepo,
  });

  final Orden orden;
  final String tenantId;
  final String vendedor;
  final OrdenRepository ordenRepo;

  @override
  State<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends State<CobrarScreen> {
  final _clienteRepo = ClienteRepository();

  // ── Estado del cobro ──────────────────────────────────────────────────────
  _MetodoPago _metodo = _MetodoPago.efectivo;
  _TipoFactura _tipoFactura = _TipoFactura.consumidorFinal;
  Cliente? _clienteSeleccionado;

  // Para efectivo
  final _entregaCtrl = TextEditingController();

  // Para mixto (efectivo + otro)
  final _mixtoEfectivoCtrl = TextEditingController();
  final _mixtoOtroCtrl = TextEditingController();

  // Búsqueda de cliente
  final _busquedaCtrl = TextEditingController();
  List<Cliente> _clientesEncontrados = [];
  bool _buscando = false;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    // Default: consumidor final
    _clienteSeleccionado = Cliente.consumidorFinal(widget.tenantId);
  }

  @override
  void dispose() {
    _entregaCtrl.dispose();
    _mixtoEfectivoCtrl.dispose();
    _mixtoOtroCtrl.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  double get _total => widget.orden.total;
  double get _entrega => double.tryParse(_entregaCtrl.text) ?? 0;
  double get _cambio => _entrega - _total;

  double get _mixtoEfectivo => double.tryParse(_mixtoEfectivoCtrl.text) ?? 0;
  double get _mixtoOtro => double.tryParse(_mixtoOtroCtrl.text) ?? 0;
  double get _mixtoTotal => _mixtoEfectivo + _mixtoOtro;

  String get _metodoPagoString => switch (_metodo) {
        _MetodoPago.efectivo => 'efectivo',
        _MetodoPago.tarjeta => 'tarjeta',
        _MetodoPago.transferencia => 'transferencia',
        _MetodoPago.mixto =>
          'mixto (efectivo: ${_fmt.format(_mixtoEfectivo)}, otro: ${_fmt.format(_mixtoOtro)})',
      };

  bool get _puedeCobrar {
    switch (_metodo) {
      case _MetodoPago.efectivo:
        return _entrega >= _total;
      case _MetodoPago.mixto:
        return _mixtoTotal >= _total;
      case _MetodoPago.tarjeta:
      case _MetodoPago.transferencia:
        return true;
    }
  }

  Future<void> _buscarCliente(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _clientesEncontrados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final found = await _clienteRepo.buscar(widget.tenantId, q.trim());
      setState(() => _clientesEncontrados = found);
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _procesarPago() async {
    setState(() => _procesando = true);
    try {
      // Si cliente no es consumidor final, actualizar en orden
      final ordenFinal = (_clienteSeleccionado != null &&
              !_clienteSeleccionado!.esConsumidorFinal)
          ? widget.orden.copyWith(
              clienteId: _clienteSeleccionado!.id,
              clienteNombre: _clienteSeleccionado!.nombreCompleto,
            )
          : widget.orden;

      await widget.ordenRepo.pagar(
        ordenFinal,
        _metodoPagoString,
        observaciones: _buildObservaciones(),
      );

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  String _buildObservaciones() {
    final parts = <String>[];
    if (_tipoFactura == _TipoFactura.electronica) {
      parts.add('Factura Electrónica');
    }
    if (_clienteSeleccionado != null &&
        !_clienteSeleccionado!.esConsumidorFinal) {
      parts.add(
          'Cliente: ${_clienteSeleccionado!.nombreCompleto} (${_clienteSeleccionado!.documentoLabel})');
    }
    return parts.join(' | ');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text('Cobrar — ${widget.orden.etiqueta}'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel izquierdo: método de pago
                Expanded(
                  flex: 2,
                  child: _PanelMetodoPago(
                    metodo: _metodo,
                    total: _total,
                    entregaCtrl: _entregaCtrl,
                    mixtoEfectivoCtrl: _mixtoEfectivoCtrl,
                    mixtoOtroCtrl: _mixtoOtroCtrl,
                    cambio: _cambio,
                    mixtoTotal: _mixtoTotal,
                    onMetodo: (m) => setState(() => _metodo = m),
                    onChanged: () => setState(() {}),
                  ),
                ),
                // Panel derecho: cliente + factura + resumen
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildClienteSection(),
                        const SizedBox(height: 20),
                        _buildFacturaSection(),
                        const SizedBox(height: 20),
                        _buildResumenOrden(),
                        const SizedBox(height: 24),
                        _buildConfirmarBtn(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          // Layout vertical (móvil)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelMetodoPago(
                  metodo: _metodo,
                  total: _total,
                  entregaCtrl: _entregaCtrl,
                  mixtoEfectivoCtrl: _mixtoEfectivoCtrl,
                  mixtoOtroCtrl: _mixtoOtroCtrl,
                  cambio: _cambio,
                  mixtoTotal: _mixtoTotal,
                  onMetodo: (m) => setState(() => _metodo = m),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildClienteSection(),
                const SizedBox(height: 16),
                _buildFacturaSection(),
                const SizedBox(height: 16),
                _buildResumenOrden(),
                const SizedBox(height: 24),
                _buildConfirmarBtn(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Sección Cliente ────────────────────────────────────────────────────────

  Widget _buildClienteSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                const Text('Cliente',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _abrirFormularioNuevoCliente(),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Cliente seleccionado
            if (_clienteSeleccionado != null)
              _ClienteChip(
                cliente: _clienteSeleccionado!,
                onClear: _clienteSeleccionado!.esConsumidorFinal
                    ? null
                    : () => setState(() => _clienteSeleccionado =
                        Cliente.consumidorFinal(widget.tenantId)),
              ),
            const SizedBox(height: 10),
            // Buscador
            TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por CI, RUC o nombre...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _buscando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) {
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (_busquedaCtrl.text == v) _buscarCliente(v);
                });
              },
            ),
            if (_clientesEncontrados.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06), blurRadius: 6)
                  ],
                ),
                child: Column(
                  children: _clientesEncontrados
                      .map((c) => ListTile(
                            dense: true,
                            title: Text(c.nombreCompleto,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(c.documentoLabel,
                                style: const TextStyle(fontSize: 11)),
                            onTap: () {
                              setState(() {
                                _clienteSeleccionado = c;
                                _clientesEncontrados = [];
                                _busquedaCtrl.clear();
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirFormularioNuevoCliente() async {
    final nuevo = await showDialog<Cliente>(
      context: context,
      builder: (_) => _NuevoClienteDialog(tenantId: widget.tenantId),
    );
    if (nuevo != null) {
      final creado = await _clienteRepo.create(nuevo);
      setState(() {
        _clienteSeleccionado = creado;
        _clientesEncontrados = [];
        _busquedaCtrl.clear();
      });
    }
  }

  // ── Sección Factura ────────────────────────────────────────────────────────

  Widget _buildFacturaSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 18),
                SizedBox(width: 8),
                Text('Tipo de Factura',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FacturaChip(
                    icon: Icons.person_outline,
                    label: 'Consumidor Final',
                    descripcion: 'Sin datos fiscales',
                    selected: _tipoFactura == _TipoFactura.consumidorFinal,
                    onTap: () => setState(
                        () => _tipoFactura = _TipoFactura.consumidorFinal),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FacturaChip(
                    icon: Icons.receipt_long,
                    label: 'Factura Electrónica',
                    descripcion: 'Con datos del cliente',
                    selected: _tipoFactura == _TipoFactura.electronica,
                    onTap: () {
                      setState(() {
                        _tipoFactura = _TipoFactura.electronica;
                        // Si era consumidor final, limpiarlo para que ingrese datos
                        if (_clienteSeleccionado?.esConsumidorFinal == true) {
                          _clienteSeleccionado = null;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Resumen de orden ───────────────────────────────────────────────────────

  Widget _buildResumenOrden() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_outlined, size: 18),
                SizedBox(width: 8),
                Text('Resumen',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            ...widget.orden.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                          '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad}x ',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      Expanded(
                          child: Text(item.nombre,
                              style: const TextStyle(fontSize: 12))),
                      Text(_fmt.format(item.subtotal),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                )),
            if (widget.orden.costoDelivery > 0) ...[
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                  Text(_fmt.format(widget.orden.costoDelivery),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  _fmt.format(_total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Botón confirmar ────────────────────────────────────────────────────────

  Widget _buildConfirmarBtn() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (_puedeCobrar && !_procesando) ? _procesarPago : null,
        icon: _procesando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
        label: Text(
          _procesando
              ? 'Procesando...'
              : 'Confirmar Cobro ${_fmt.format(_total)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _puedeCobrar ? Colors.green.shade600 : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

// ─── Panel Método de Pago ─────────────────────────────────────────────────────

class _PanelMetodoPago extends StatelessWidget {
  const _PanelMetodoPago({
    required this.metodo,
    required this.total,
    required this.entregaCtrl,
    required this.mixtoEfectivoCtrl,
    required this.mixtoOtroCtrl,
    required this.cambio,
    required this.mixtoTotal,
    required this.onMetodo,
    required this.onChanged,
  });
  final _MetodoPago metodo;
  final double total, cambio, mixtoTotal;
  final TextEditingController entregaCtrl, mixtoEfectivoCtrl, mixtoOtroCtrl;
  final ValueChanged<_MetodoPago> onMetodo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Método de Pago',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          // Chips de métodos
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PayMethodBtn(
                icon: Icons.payments_outlined,
                label: 'Efectivo',
                selected: metodo == _MetodoPago.efectivo,
                color: Colors.green,
                onTap: () => onMetodo(_MetodoPago.efectivo),
              ),
              _PayMethodBtn(
                icon: Icons.credit_card,
                label: 'Tarjeta',
                selected: metodo == _MetodoPago.tarjeta,
                color: Colors.blue,
                onTap: () => onMetodo(_MetodoPago.tarjeta),
              ),
              _PayMethodBtn(
                icon: Icons.account_balance_outlined,
                label: 'Transferencia',
                selected: metodo == _MetodoPago.transferencia,
                color: Colors.teal,
                onTap: () => onMetodo(_MetodoPago.transferencia),
              ),
              _PayMethodBtn(
                icon: Icons.compare_arrows,
                label: 'Mixto',
                selected: metodo == _MetodoPago.mixto,
                color: Colors.purple,
                onTap: () => onMetodo(_MetodoPago.mixto),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Campos según método
          if (metodo == _MetodoPago.efectivo) ...[
            const Text('Efectivo recibido:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: entregaCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cambio >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: cambio >= 0
                        ? Colors.green.shade200
                        : Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(cambio >= 0 ? 'Cambio:' : 'Faltan:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cambio >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700)),
                  Text(
                    NumberFormat('\$#,##0.00', 'en_US').format(cambio.abs()),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: cambio >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (metodo == _MetodoPago.mixto) ...[
            const Text('Distribución del pago:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: mixtoEfectivoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Efectivo',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: mixtoOtroCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Tarjeta / Transferencia',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            _ResumenMixto(total: total, mixtoTotal: mixtoTotal),
          ],
          if (metodo == _MetodoPago.tarjeta ||
              metodo == _MetodoPago.transferencia) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                      metodo == _MetodoPago.tarjeta
                          ? Icons.credit_card
                          : Icons.account_balance_outlined,
                      color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metodo == _MetodoPago.tarjeta
                          ? 'Se cobrará el total mediante tarjeta.'
                          : 'Se cobrará mediante transferencia bancaria.',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayMethodBtn extends StatelessWidget {
  const _PayMethodBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.black54,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ResumenMixto extends StatelessWidget {
  const _ResumenMixto({required this.total, required this.mixtoTotal});
  final double total, mixtoTotal;

  @override
  Widget build(BuildContext context) {
    final diferencia = mixtoTotal - total;
    final nf = NumberFormat('\$#,##0.00', 'en_US');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: diferencia >= 0 ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: diferencia >= 0
                ? Colors.green.shade200
                : Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 12)),
              Text(nf.format(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Suma pagos:', style: TextStyle(fontSize: 12)),
              Text(nf.format(mixtoTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const Divider(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(diferencia >= 0 ? 'Cambio:' : 'Faltan:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: diferencia >= 0
                          ? Colors.green.shade700
                          : Colors.orange.shade700)),
              Text(
                nf.format(diferencia.abs()),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: diferencia >= 0
                        ? Colors.green.shade700
                        : Colors.orange.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Chip de cliente seleccionado ────────────────────────────────────────────

class _ClienteChip extends StatelessWidget {
  const _ClienteChip({required this.cliente, this.onClear});
  final Cliente cliente;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cliente.esConsumidorFinal
            ? Colors.grey.shade100
            : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: cliente.esConsumidorFinal
                ? Colors.grey.shade300
                : AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            cliente.esConsumidorFinal ? Icons.person_outline : Icons.person,
            color: cliente.esConsumidorFinal ? Colors.grey : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cliente.nombreCompleto,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cliente.esConsumidorFinal
                            ? Colors.black54
                            : AppColors.primary,
                        fontSize: 13)),
                if (!cliente.esConsumidorFinal)
                  Text(cliente.documentoLabel,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: Colors.black38),
            ),
        ],
      ),
    );
  }
}

// ─── Chip de tipo de factura ──────────────────────────────────────────────────

class _FacturaChip extends StatelessWidget {
  const _FacturaChip({
    required this.icon,
    required this.label,
    required this.descripcion,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label, descripcion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
              width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 24, color: selected ? AppColors.primary : Colors.grey),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: selected ? AppColors.primary : Colors.black54)),
            Text(descripcion,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.black38)),
          ],
        ),
      ),
    );
  }
}

// ─── Formulario Nuevo Cliente ─────────────────────────────────────────────────

class _NuevoClienteDialog extends StatefulWidget {
  const _NuevoClienteDialog({required this.tenantId});
  final String tenantId;

  @override
  State<_NuevoClienteDialog> createState() => _NuevoClienteDialogState();
}

class _NuevoClienteDialogState extends State<_NuevoClienteDialog> {
  TipoDocumento _tipoDoc = TipoDocumento.ci;
  final _docCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _docCtrl.dispose();
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _celularCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _provinciaCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (_docCtrl.text.trim().isEmpty || _nombresCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final cliente = Cliente(
        id: '',
        tenantId: widget.tenantId,
        tipoDocumento: _tipoDoc,
        numeroDocumento: _docCtrl.text.trim(),
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        celular: _celularCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        provincia: _provinciaCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, cliente);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Cliente'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tipo de documento
              Row(
                children: [
                  const Text('Tipo doc:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 10),
                  SegmentedButton<TipoDocumento>(
                    segments: const [
                      ButtonSegment(value: TipoDocumento.ci, label: Text('CI')),
                      ButtonSegment(
                          value: TipoDocumento.ruc, label: Text('RUC')),
                      ButtonSegment(
                          value: TipoDocumento.pasaporte,
                          label: Text('Pasaporte')),
                    ],
                    selected: {_tipoDoc},
                    onSelectionChanged: (s) =>
                        setState(() => _tipoDoc = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _docCtrl,
                decoration: InputDecoration(
                  labelText:
                      '${_tipoDoc == TipoDocumento.ci ? 'Cédula' : _tipoDoc == TipoDocumento.ruc ? 'RUC' : 'Pasaporte'} *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nombresCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombres *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _apellidosCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _celularCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _provinciaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Provincia',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _guardar,
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
