import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/movimiento_inventario.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/repositories/movimiento_inventario_repository.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _busquedaCtrl = TextEditingController();
  final TextEditingController _cantidadCtrl = TextEditingController();
  final TextEditingController _motivoCtrl = TextEditingController();
  final ProductRepository _productRepo = ProductRepository();
  final MovimientoInventarioRepository _movRepo =
      MovimientoInventarioRepository();
  String? _tenantIdForStreams;
  Stream<List<Product>>? _productsStream;
  Stream<List<MovimientoInventario>>? _movimientosStream;

  String _busqueda = '';
  String _tipoMovimiento = 'entrada';
  Product? _productoSeleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _busquedaCtrl.addListener(
      () => setState(() => _busqueda = _busquedaCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    _busquedaCtrl.dispose();
    _cantidadCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarMovimiento(String tenantId, String operador) async {
    final producto = _productoSeleccionado;
    if (producto == null) {
      _mostrarError('Selecciona un producto');
      return;
    }
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (cantidad == null || cantidad <= 0) {
      _mostrarError('Ingresa una cantidad válida (número entero > 0)');
      return;
    }
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      _mostrarError('Ingresa un motivo');
      return;
    }

    int stockAnterior = producto.stock;
    int stockNuevo;
    switch (_tipoMovimiento) {
      case 'entrada':
        stockNuevo = stockAnterior + cantidad;
        break;
      case 'salida':
        stockNuevo = (stockAnterior - cantidad).clamp(0, 999999);
        break;
      case 'ajuste':
        stockNuevo = cantidad;
        break;
      default:
        stockNuevo = stockAnterior;
    }

    setState(() => _guardando = true);
    try {
      final mov = MovimientoInventario(
        id: '',
        tenantId: tenantId,
        productoId: producto.id,
        productoNombre: producto.nombre,
        tipo: _tipoMovimiento,
        cantidad: cantidad,
        stockAnterior: stockAnterior,
        stockNuevo: stockNuevo,
        motivo: motivo,
        operador: operador,
        fecha: DateTime.now(),
      );
      await _movRepo.registrar(mov, stockNuevo);
      if (mounted) {
        setState(() {
          _productoSeleccionado = null;
          _cantidadCtrl.clear();
          _motivoCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movimiento registrado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _ensureTenantStreams(String tenantId) {
    if (_tenantIdForStreams == tenantId &&
        _productsStream != null &&
        _movimientosStream != null) {
      return;
    }

    _tenantIdForStreams = tenantId;
    _productsStream = _productRepo.watchByTenant(tenantId);
    _movimientosStream = _movRepo.watchByTenant(tenantId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenantId = auth.tenantId;
    final operador = auth.loginUsername;
    _ensureTenantStreams(tenantId);
    final productsStream = _productsStream;
    if (productsStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Inventario'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.warehouse_outlined), text: 'Stock'),
            Tab(icon: Icon(Icons.swap_vert), text: 'Movimiento'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: productsStream,
        builder: (context, snap) {
          final products = snap.data ?? [];
          return TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStock(products),
              _buildMovimiento(products, tenantId, operador),
              _buildHistorial(),
            ],
          );
        },
      ),
    );
  }

  // ── Tab 0: Stock Actual ───────────────────────────────────────────────────

  Widget _buildStock(List<Product> products) {
    final agotados = products.where((p) => p.stock <= 0).length;
    final bajos =
        products.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).length;
    final ok = products.where((p) => p.stock > p.stockMinimo).length;

    final filtered = products
        .where((p) =>
            _busqueda.isEmpty ||
            p.nombre.toLowerCase().contains(_busqueda) ||
            p.codigo.toLowerCase().contains(_busqueda))
        .toList()
      ..sort((a, b) {
        // Agotados primero, luego bajo stock, luego ok
        int prioridad(Product p) =>
            p.stock <= 0 ? 0 : (p.stock <= p.stockMinimo ? 1 : 2);
        return prioridad(a).compareTo(prioridad(b));
      });

    return Column(
      children: [
        // Resumen de alertas
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StockChip(label: 'Agotados', value: agotados, color: Colors.red),
              const SizedBox(width: 8),
              _StockChip(
                  label: 'Stock bajo', value: bajos, color: Colors.orange),
              const SizedBox(width: 8),
              _StockChip(
                  label: 'Disponibles', value: ok, color: AppColors.success),
            ],
          ),
        ),
        // Buscador
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _busquedaCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _busquedaCtrl.clear();
                        setState(() => _busqueda = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Sin productos'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _StockRow(product: filtered[i]),
                ),
        ),
      ],
    );
  }

  // ── Tab 1: Registrar Movimiento ───────────────────────────────────────────

  Widget _buildMovimiento(
      List<Product> products, String tenantId, String operador) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Registrar movimiento',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Tipo
                  const Text('TIPO DE MOVIMIENTO',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'entrada',
                          label: Text('Entrada'),
                          icon: Icon(Icons.add_circle_outline)),
                      ButtonSegment(
                          value: 'salida',
                          label: Text('Salida'),
                          icon: Icon(Icons.remove_circle_outline)),
                      ButtonSegment(
                          value: 'ajuste',
                          label: Text('Ajuste'),
                          icon: Icon(Icons.tune)),
                    ],
                    selected: {_tipoMovimiento},
                    onSelectionChanged: (s) =>
                        setState(() => _tipoMovimiento = s.first),
                  ),
                  const SizedBox(height: 20),

                  // Producto
                  const Text('PRODUCTO',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Product>(
                    value: _productoSeleccionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '— Selecciona un producto —',
                    ),
                    items: products
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p.nombre} (stock: ${p.stock})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (p) => setState(() => _productoSeleccionado = p),
                  ),
                  const SizedBox(height: 16),

                  // Cantidad
                  const Text('CANTIDAD',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: _tipoMovimiento == 'ajuste'
                          ? 'Nuevo stock absoluto'
                          : 'Cantidad a ${_tipoMovimiento == "entrada" ? "ingresar" : "retirar"}',
                    ),
                  ),
                  if (_productoSeleccionado != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Stock actual: ${_productoSeleccionado!.stock}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Motivo
                  const Text('MOTIVO',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _motivoCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Compra, Devolución, Inventario físico...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _guardando
                          ? null
                          : () => _guardarMovimiento(tenantId, operador),
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Guardar movimiento'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 2: Historial ──────────────────────────────────────────────────────

  Widget _buildHistorial() {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final movimientosStream = _movimientosStream;
    if (movimientosStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<MovimientoInventario>>(
      stream: movimientosStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final movs = snap.data ?? [];
        if (movs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Sin movimientos registrados',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: movs.length,
          itemBuilder: (_, i) {
            final m = movs[i];
            final isEntrada = m.tipo == 'entrada';
            final isAjuste = m.tipo == 'ajuste';
            final color = isAjuste
                ? Colors.blue
                : (isEntrada ? AppColors.success : Colors.red);
            final icon = isAjuste
                ? Icons.tune
                : (isEntrada
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color),
                ),
                title: Text(m.productoNombre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.tipo.toUpperCase()} · ${m.motivo}',
                        style: const TextStyle(fontSize: 12)),
                    Text(
                        '${m.stockAnterior} → ${m.stockNuevo}  |  ${fmt.format(m.fecha)} · ${m.operador}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                trailing: Text(
                  isEntrada
                      ? '+${m.cantidad}'
                      : (isAjuste ? '=${m.stockNuevo}' : '-${m.cantidad}'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de apoyo
// ─────────────────────────────────────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  const _StockRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final agotado = product.stock <= 0;
    final bajo = !agotado && product.stock <= product.stockMinimo;
    final color =
        agotado ? Colors.red : (bajo ? Colors.orange : AppColors.success);
    final label = agotado ? 'AGOTADO' : (bajo ? 'BAJO' : 'OK');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(product.codigo,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${product.stock}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text('min: ${product.stockMinimo}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}
