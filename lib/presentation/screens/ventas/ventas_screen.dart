import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/models/venta.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/data/repositories/venta_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _busquedaCtrl = TextEditingController();
  final ProductRepository _productRepo = ProductRepository();
  final VentaRepository _ventaRepo = VentaRepository();

  // Carrito: productoId → VentaItem
  final Map<String, VentaItem> _carrito = {};
  String _metodoPago = 'efectivo';
  bool _guardando = false;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _busquedaCtrl.addListener(
      () => setState(() => _busqueda = _busquedaCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _agregarAlCarrito(Product p) {
    setState(() {
      if (_carrito.containsKey(p.id)) {
        final item = _carrito[p.id]!;
        _carrito[p.id] = item.conCantidad(item.cantidad + 1);
      } else {
        _carrito[p.id] = VentaItem(
          productoId: p.id,
          nombre: p.nombre,
          codigo: p.codigo,
          precio: p.precioVenta,
          cantidad: 1,
          subtotal: p.precioVenta,
          impuesto: p.impuesto,
        );
      }
    });
  }

  void _ajustarCantidad(String productoId, double delta) {
    setState(() {
      final item = _carrito[productoId];
      if (item == null) return;
      final nueva = item.cantidad + delta;
      if (nueva <= 0) {
        _carrito.remove(productoId);
      } else {
        _carrito[productoId] = item.conCantidad(nueva);
      }
    });
  }

  void _limpiarCarrito() {
    setState(() {
      _carrito.clear();
      _metodoPago = 'efectivo';
    });
  }

  double get _total => _carrito.values.fold(0.0, (a, i) => a + i.subtotal);

  Future<void> _registrarVenta() async {
    if (_carrito.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final tenantId = auth.tenantId;
    final vendedor = auth.loginUsername;
    setState(() => _guardando = true);
    try {
      final venta = Venta(
        id: '',
        tenantId: tenantId,
        items: _carrito.values.toList(),
        subtotal: _total,
        totalImpuesto: 0,
        total: _total,
        metodoPago: _metodoPago,
        vendedor: vendedor,
        estado: 'completada',
        fecha: DateTime.now(),
        creadoPor: vendedor,
      );
      await _ventaRepo.create(venta);
      _limpiarCarrito();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta registrada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenantId = auth.tenantId;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171B21),
        foregroundColor: Colors.white,
        title: const Text('Ventas'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale_outlined), text: 'Nueva Venta'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildNuevaVenta(tenantId),
          _buildHistorial(tenantId),
        ],
      ),
    );
  }

  // ── Tab 0: Nueva Venta ────────────────────────────────────────────────────

  Widget _buildNuevaVenta(String tenantId) {
    return StreamBuilder<List<Product>>(
      stream: _productRepo.watchByTenant(tenantId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final productos = (snap.data ?? [])
            .where((p) => p.activo && p.mostrarEnVentas)
            .where((p) =>
                _busqueda.isEmpty ||
                p.nombre.toLowerCase().contains(_busqueda) ||
                p.codigo.toLowerCase().contains(_busqueda))
            .toList();

        return LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 800;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildCatalogo(productos)),
                Container(width: 1, color: Colors.grey.shade200),
                SizedBox(
                  width: 340,
                  child: _buildCarritoPanel(),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: _buildCatalogo(productos)),
              if (_carrito.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: Container(
                    color: Colors.white,
                    child: _buildCarritoPanel(),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  Widget _buildCatalogo(List<Product> productos) {
    return Column(
      children: [
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
          child: productos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Sin productos disponibles para ventas',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: productos.length,
                  itemBuilder: (_, i) => _ProductCard(
                    product: productos[i],
                    enCarrito: _carrito.containsKey(productos[i].id),
                    cantidad: _carrito[productos[i].id]?.cantidad.toInt() ?? 0,
                    onAdd: () => _agregarAlCarrito(productos[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCarritoPanel() {
    final items = _carrito.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF171B21),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Carrito (${items.length})',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: _limpiarCarrito,
                  child: const Text('Limpiar',
                      style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Agrega productos del catálogo',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  dense: true,
                  title: Text(item.nombre,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('\$${item.precio.toStringAsFixed(2)} c/u'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => _ajustarCantidad(item.productoId, -1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          item.cantidad % 1 == 0
                              ? item.cantidad.toInt().toString()
                              : item.cantidad.toStringAsFixed(2),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => _ajustarCantidad(item.productoId, 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '\$${item.subtotal.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _metodoPago,
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(
                    value: 'transferencia', child: Text('Transferencia')),
              ],
              onChanged: (v) => setState(() => _metodoPago = v!),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: _guardando ? null : _registrarVenta,
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Registrar Venta'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(42)),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tab 1: Historial ──────────────────────────────────────────────────────

  Widget _buildHistorial(String tenantId) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return StreamBuilder<List<Venta>>(
      stream: _ventaRepo.watchByTenant(tenantId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ventas = snap.data ?? [];
        if (ventas.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Sin ventas registradas',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ],
            ),
          );
        }

        // Métricas rápidas
        final totalHoy = ventas
            .where((v) =>
                v.estado == 'completada' &&
                v.fecha.day == DateTime.now().day &&
                v.fecha.month == DateTime.now().month &&
                v.fecha.year == DateTime.now().year)
            .fold(0.0, (a, v) => a + v.total);

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _MetricChip(
                    icon: Icons.today,
                    label: 'Hoy',
                    value: '\$${totalHoy.toStringAsFixed(2)}',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _MetricChip(
                    icon: Icons.receipt_long_outlined,
                    label: 'Total registros',
                    value: ventas.length.toString(),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ventas.length,
                itemBuilder: (_, i) {
                  final v = ventas[i];
                  final anulada = v.estado == 'anulada';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            anulada ? Colors.red.shade50 : Colors.green.shade50,
                        child: Icon(
                          anulada
                              ? Icons.cancel_outlined
                              : Icons.check_circle_outline,
                          color: anulada ? Colors.red : AppColors.success,
                        ),
                      ),
                      title: Text(
                        '\$${v.total.toStringAsFixed(2)} — ${v.metodoPago}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration:
                              anulada ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        '${fmt.format(v.fecha)} · ${v.vendedor}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: v.items
                          .map((item) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.circle, size: 6),
                                title: Text(item.nombre),
                                subtitle: Text(
                                    '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(2)} × \$${item.precio.toStringAsFixed(2)}'),
                                trailing: Text(
                                    '\$${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de apoyo
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.enCarrito,
    required this.cantidad,
    required this.onAdd,
  });

  final Product product;
  final bool enCarrito;
  final int cantidad;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imagenBase64 != null
                      ? Image.memory(
                          base64Decode(product.imagenBase64!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${product.precioVenta.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  if (enCarrito)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+$cantidad',
                        style:
                            TextStyle(fontSize: 10, color: AppColors.success),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      child:
          const Center(child: Icon(Icons.image_outlined, color: Colors.grey)),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
