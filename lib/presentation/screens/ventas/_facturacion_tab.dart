import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/orden.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/repositories/orden_repository.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

final _fmt = NumberFormat('\$#,##0.00', 'en_US');
final _fmtHora = DateFormat('HH:mm');
final _fmtFecha = DateFormat('dd/MM HH:mm');

class FacturacionTab extends StatefulWidget {
  const FacturacionTab({super.key, required this.tipoComercio});
  final String tipoComercio;

  @override
  State<FacturacionTab> createState() => _FacturacionTabState();
}

class _FacturacionTabState extends State<FacturacionTab> {
  final _ordenRepo = OrdenRepository();
  final _productRepo = ProductRepository();
  final _busquedaCtrl = TextEditingController();

  Orden? _ordenSeleccionada;
  String _filtroTipo = 'todos';
  String _busqueda = '';

  // Carrito local (sincronizado con Firestore al pagar)
  List<OrdenItem> _carritoLocal = [];

  bool get _esRestaurante =>
      widget.tipoComercio == 'restaurante' || widget.tipoComercio == 'kiosko';

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

  void _seleccionarOrden(Orden orden) {
    setState(() {
      _ordenSeleccionada = orden;
      _carritoLocal = List.from(orden.items);
    });
  }

  void _agregarProducto(Product p) {
    setState(() {
      final idx = _carritoLocal.indexWhere((i) => i.productoId == p.id);
      if (idx >= 0) {
        final item = _carritoLocal[idx];
        _carritoLocal[idx] = item.conCantidad(item.cantidad + 1);
      } else {
        _carritoLocal.add(OrdenItem(
          productoId: p.id,
          nombre: p.nombre,
          codigo: p.codigo,
          precio: p.precioVenta,
          cantidad: 1,
          subtotal: p.precioVenta,
          impuesto: p.impuesto,
        ));
      }
    });
  }

  void _cambiarCantidad(int idx, double delta) {
    setState(() {
      final item = _carritoLocal[idx];
      final nueva = item.cantidad + delta;
      if (nueva <= 0) {
        _carritoLocal.removeAt(idx);
      } else {
        _carritoLocal[idx] = item.conCantidad(nueva);
      }
    });
  }

  void _eliminarItem(int idx) {
    setState(() => _carritoLocal.removeAt(idx));
  }

  double get _subtotalLocal =>
      _carritoLocal.fold(0.0, (a, i) => a + i.subtotal);

  double get _totalLocal =>
      _subtotalLocal + (_ordenSeleccionada?.costoDelivery ?? 0.0);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenantId = auth.tenantId;
    final vendedor = auth.loginUsername;

    return StreamBuilder<List<Orden>>(
      stream: _ordenRepo.watchAbiertas(tenantId),
      builder: (context, snap) {
        final todasOrdenes = snap.data ?? [];

        // Sincronizar orden seleccionada con el stream (sin sobrescribir carrito local)
        if (_ordenSeleccionada != null) {
          final actualizada = todasOrdenes
              .where((o) => o.id == _ordenSeleccionada!.id)
              .firstOrNull;
          if (actualizada == null) {
            // La orden ya fue pagada/cancelada
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _ordenSeleccionada = null;
                  _carritoLocal = [];
                });
              }
            });
          }
        }

        final ordenesFiltradas = _filtroTipo == 'todos'
            ? todasOrdenes
            : todasOrdenes.where((o) => o.tipo == _filtroTipo).toList();

        return LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 860;
          return Column(
            children: [
              _buildToolbar(context, tenantId, vendedor, todasOrdenes),
              Expanded(
                child: wide
                    ? _buildWideBody(ordenesFiltradas, tenantId, vendedor, auth)
                    : _buildNarrowBody(
                        context, ordenesFiltradas, tenantId, vendedor, auth),
              ),
            ],
          );
        });
      },
    );
  }

  // ─── Toolbar ─────────────────────────────────────────────────────────────

  Widget _buildToolbar(BuildContext context, String tenantId, String vendedor,
      List<Orden> todasOrdenes) {
    final chips = <_FiltroChip>[
      const _FiltroChip('todos', 'Todos', Icons.grid_view_rounded),
      if (_esRestaurante)
        const _FiltroChip('mesa', 'Mesa', Icons.table_restaurant),
      const _FiltroChip('retiro', 'Retiro', Icons.store_outlined),
      const _FiltroChip('domicilio', 'Domicilio', Icons.delivery_dining),
      const _FiltroChip('rapida', 'Rápida', Icons.flash_on_rounded),
    ];

    return Container(
      color: const Color(0xFF1A2035),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => _mostrarNuevaOrdenDialog(
                context, tenantId, vendedor, todasOrdenes),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva Orden'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _filtroTipo == c.value,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(c.icon, size: 14),
                                const SizedBox(width: 4),
                                Text(c.label),
                              ],
                            ),
                            onSelected: (_) =>
                                setState(() => _filtroTipo = c.value),
                            selectedColor: AppColors.accent.withOpacity(0.3),
                            labelStyle: TextStyle(
                              color: _filtroTipo == c.value
                                  ? AppColors.accent
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            backgroundColor: Colors.white10,
                            checkmarkColor: AppColors.accent,
                            side: BorderSide(
                              color: _filtroTipo == c.value
                                  ? AppColors.accent
                                  : Colors.white24,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wide layout ─────────────────────────────────────────────────────────

  Widget _buildWideBody(List<Orden> ordenes, String tenantId, String vendedor,
      AuthProvider auth) {
    return Row(
      children: [
        // Panel izquierdo: lista de órdenes
        Container(
          width: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: _buildOrdenesList(ordenes),
        ),
        // Panel derecho: detalle
        Expanded(
          child: _ordenSeleccionada == null
              ? _buildPlaceholderDetalle()
              : _buildOrdenDetalle(tenantId, auth),
        ),
      ],
    );
  }

  // ─── Narrow layout ───────────────────────────────────────────────────────

  Widget _buildNarrowBody(BuildContext context, List<Orden> ordenes,
      String tenantId, String vendedor, AuthProvider auth) {
    if (_ordenSeleccionada != null) {
      return Stack(
        children: [
          _buildOrdenDetalle(tenantId, auth),
          Positioned(
            top: 8,
            left: 8,
            child: FloatingActionButton.small(
              heroTag: 'back_to_list',
              onPressed: () => setState(() {
                _ordenSeleccionada = null;
                _carritoLocal = [];
              }),
              backgroundColor: const Color(0xFF1A2035),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ],
      );
    }
    return _buildOrdenesList(ordenes);
  }

  // ─── Lista de órdenes ────────────────────────────────────────────────────

  Widget _buildOrdenesList(List<Orden> ordenes) {
    if (ordenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No hay órdenes abiertas',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ordenes.length,
      itemBuilder: (_, i) {
        final orden = ordenes[i];
        final selected = _ordenSeleccionada?.id == orden.id;
        return _OrdenCard(
          orden: orden,
          selected: selected,
          onTap: () => _seleccionarOrden(orden),
        );
      },
    );
  }

  // ─── Placeholder detalle ─────────────────────────────────────────────────

  Widget _buildPlaceholderDetalle() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Selecciona una orden\no crea una nueva',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, color: Colors.grey.shade500, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── Detalle de orden ────────────────────────────────────────────────────

  Widget _buildOrdenDetalle(String tenantId, AuthProvider auth) {
    final orden = _ordenSeleccionada!;
    return Column(
      children: [
        // Header de la orden
        _buildOrdenHeader(orden, auth),
        // Body: catálogo + carrito
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth >= 700;
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCatalogo(tenantId, orden),
                  ),
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(left: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: _buildCarritoPanel(orden, auth),
                  ),
                ],
              );
            }
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: 'Catálogo'),
                      Tab(text: 'Carrito'),
                    ],
                    labelColor: AppColors.primary,
                    indicatorColor: AppColors.accent,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCatalogo(tenantId, orden),
                        _buildCarritoPanel(orden, auth),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOrdenHeader(Orden orden, AuthProvider auth) {
    final (icon, color) = _iconoPorTipo(orden.tipo);
    String subtitle = '';
    if (orden.tipo == 'mesa') subtitle = 'Mesa ${orden.numeroMesa}';
    if (orden.tipo == 'retiro' || orden.tipo == 'domicilio') {
      subtitle = [
        if (orden.clienteNombre?.isNotEmpty ?? false) orden.clienteNombre!,
        if (orden.clienteTelefono?.isNotEmpty ?? false) orden.clienteTelefono!,
      ].join(' · ');
    }
    if (orden.tipo == 'domicilio' &&
        (orden.clienteDireccion?.isNotEmpty ?? false)) {
      subtitle += '\n${orden.clienteDireccion}';
    }

    return Container(
      color: const Color(0xFFF8F9FB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orden.etiqueta,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text('Abierta ${_fmtFecha.format(orden.fechaCreacion)}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          // Cancelar orden
          IconButton(
            onPressed: () => _confirmarCancelar(orden),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cancelar orden',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  // ─── Catálogo de productos ───────────────────────────────────────────────

  Widget _buildCatalogo(String tenantId, Orden orden) {
    return StreamBuilder<List<Product>>(
      stream: _productRepo.watchByTenant(tenantId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final todos = (snap.data ?? []).where((p) => p.activo).toList();
        final filtrados = _busqueda.isEmpty
            ? todos
            : todos
                .where((p) =>
                    p.nombre.toLowerCase().contains(_busqueda) ||
                    p.codigo.toLowerCase().contains(_busqueda) ||
                    (p.seccionNombre?.toLowerCase().contains(_busqueda) ??
                        false))
                .toList();

        return Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _busquedaCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            setState(() => _busqueda = '');
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24)),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
              ),
            ),
            // Grid de productos
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text('Sin productos',
                          style: TextStyle(color: Colors.grey.shade500)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: filtrados[i],
                        onTap: () => _agregarProducto(filtrados[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ─── Panel carrito ───────────────────────────────────────────────────────

  Widget _buildCarritoPanel(Orden orden, AuthProvider auth) {
    final costoDelivery = orden.costoDelivery;
    return Column(
      children: [
        // Título
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 18),
              const SizedBox(width: 8),
              const Text('Carrito',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text('${_carritoLocal.length} ítems',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        // Lista de ítems
        Expanded(
          child: _carritoLocal.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_shopping_cart,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('Agrega productos\ndel catálogo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _carritoLocal.length,
                  itemBuilder: (_, i) {
                    final item = _carritoLocal[i];
                    return _CarritoItemTile(
                      item: item,
                      onIncrease: () => _cambiarCantidad(i, 1),
                      onDecrease: () => _cambiarCantidad(i, -1),
                      onRemove: () => _eliminarItem(i),
                    );
                  },
                ),
        ),
        // Resumen y botón pagar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              if (orden.tipo == 'domicilio' && costoDelivery > 0)
                _ResumenRow(
                    label: 'Subtotal', value: _fmt.format(_subtotalLocal)),
              if (orden.tipo == 'domicilio' && costoDelivery > 0)
                _ResumenRow(
                    label: 'Delivery',
                    value: _fmt.format(costoDelivery),
                    color: Colors.orange),
              _ResumenRow(
                  label: 'TOTAL',
                  value: _fmt.format(_totalLocal),
                  bold: true,
                  large: true),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _carritoLocal.isEmpty
                      ? null
                      : () => _mostrarPagarDialog(context, orden, auth),
                  icon: const Icon(Icons.payment),
                  label: Text('Pagar ${_fmt.format(_totalLocal)}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Diálogo nueva orden ─────────────────────────────────────────────────

  Future<void> _mostrarNuevaOrdenDialog(BuildContext context, String tenantId,
      String vendedor, List<Orden> ordenesAbiertas) async {
    await showDialog(
      context: context,
      builder: (ctx) => _NuevaOrdenDialog(
        esRestaurante: _esRestaurante,
        ordenesAbiertas: ordenesAbiertas,
        onCrear:
            (tipo, numeroMesa, nombre, telefono, direccion, delivery) async {
          final ahora = DateTime.now();
          final nueva = Orden(
            id: '',
            tenantId: tenantId,
            tipo: tipo,
            items: const [],
            estado: 'abierta',
            vendedor: vendedor,
            fechaCreacion: ahora,
            numeroMesa: numeroMesa,
            clienteNombre: nombre?.isEmpty == true ? null : nombre,
            clienteTelefono: telefono?.isEmpty == true ? null : telefono,
            clienteDireccion: direccion?.isEmpty == true ? null : direccion,
            costoDelivery: delivery ?? 0,
          );
          final creada = await _ordenRepo.create(nueva);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) {
            setState(() {
              _ordenSeleccionada = creada;
              _carritoLocal = [];
            });
          }
        },
      ),
    );
  }

  // ─── Diálogo pagar ───────────────────────────────────────────────────────

  Future<void> _mostrarPagarDialog(
      BuildContext context, Orden orden, AuthProvider auth) async {
    await showDialog(
      context: context,
      builder: (ctx) => _PagarDialog(
        orden: orden.copyWith(items: _carritoLocal),
        total: _totalLocal,
        onPagar: (metodoPago, obs) async {
          final ordenFinal = orden.copyWith(items: _carritoLocal);
          await _ordenRepo.pagar(ordenFinal, metodoPago, observaciones: obs);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) {
            setState(() {
              _ordenSeleccionada = null;
              _carritoLocal = [];
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('✓ Venta registrada — ${_fmt.format(_totalLocal)}'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  // ─── Confirmar cancelar ──────────────────────────────────────────────────

  Future<void> _confirmarCancelar(Orden orden) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar orden'),
        content: Text('¿Cancelar "${orden.etiqueta}"? '
            'Esta acción no puede deshacerse.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancelar orden'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _ordenRepo.cancelar(orden.id);
      if (mounted)
        setState(() {
          _ordenSeleccionada = null;
          _carritoLocal = [];
        });
    }
  }

  static (IconData, Color) _iconoPorTipo(String tipo) => switch (tipo) {
        'mesa' => (Icons.table_restaurant, Colors.purple),
        'retiro' => (Icons.store_outlined, Colors.blue),
        'domicilio' => (Icons.delivery_dining, Colors.orange),
        _ => (Icons.flash_on_rounded, Colors.teal),
      };
}

// ─── Widgets reutilizables ────────────────────────────────────────────────

class _FiltroChip {
  const _FiltroChip(this.value, this.label, this.icon);
  final String value, label;
  final IconData icon;
}

class _OrdenCard extends StatelessWidget {
  const _OrdenCard(
      {required this.orden, required this.selected, required this.onTap});
  final Orden orden;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconoPorTipo(orden.tipo);
    final mins = DateTime.now().difference(orden.fechaCreacion).inMinutes;
    final tiempoStr =
        mins < 60 ? '${mins}m' : '${(mins / 60).floor()}h${mins % 60}m';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(orden.etiqueta,
                      style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                          color:
                              selected ? AppColors.primary : Colors.black87)),
                  Row(
                    children: [
                      Text('${orden.items.length} ítems · $tiempoStr',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            Text(_fmt.format(orden.total),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: selected ? AppColors.primary : Colors.black87)),
          ],
        ),
      ),
    );
  }

  static (IconData, Color) _iconoPorTipo(String tipo) => switch (tipo) {
        'mesa' => (Icons.table_restaurant, Colors.purple),
        'retiro' => (Icons.store_outlined, Colors.blue),
        'domicilio' => (Icons.delivery_dining, Colors.orange),
        _ => (Icons.flash_on_rounded, Colors.teal),
      };
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: product.imagenBase64 != null
                    ? Image.memory(
                        base64Decode(product.imagenBase64!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder(),
                      )
                    : _imgPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt.format(product.precioVenta),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: Colors.grey.shade100,
        child: Icon(Icons.inventory_2_outlined,
            color: Colors.grey.shade300, size: 32),
      );
}

class _CarritoItemTile extends StatelessWidget {
  const _CarritoItemTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });
  final OrdenItem item;
  final VoidCallback onIncrease, onDecrease, onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Cantidad controls
          _QtyBtn(Icons.remove, onDecrease),
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
                item.cantidad % 1 == 0
                    ? item.cantidad.toInt().toString()
                    : item.cantidad.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          _QtyBtn(Icons.add, onIncrease),
          const SizedBox(width: 8),
          // Nombre
          Expanded(
            child: Text(item.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          // Subtotal
          Text(_fmt.format(item.subtotal),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14),
        ),
      );
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
    this.color,
  });
  final String label, value;
  final bool bold, large;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: large ? 15 : 13,
                    color: color ?? Colors.black87)),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: large ? 15 : 13,
                    color: color ?? AppColors.primary)),
          ],
        ),
      );
}

// ─── Diálogo Nueva Orden ──────────────────────────────────────────────────

typedef _OnCrearOrden = Future<void> Function(
  String tipo,
  int? numeroMesa,
  String? nombre,
  String? telefono,
  String? direccion,
  double? delivery,
);

class _NuevaOrdenDialog extends StatefulWidget {
  const _NuevaOrdenDialog({
    required this.esRestaurante,
    required this.ordenesAbiertas,
    required this.onCrear,
  });
  final bool esRestaurante;
  final List<Orden> ordenesAbiertas;
  final _OnCrearOrden onCrear;

  @override
  State<_NuevaOrdenDialog> createState() => _NuevaOrdenDialogState();
}

class _NuevaOrdenDialogState extends State<_NuevaOrdenDialog> {
  String? _tipoSeleccionado;
  int? _mesaSeleccionada;
  bool _cargando = false;

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  Set<int> get _mesasOcupadas => widget.ordenesAbiertas
      .where((o) => o.tipo == 'mesa' && o.numeroMesa != null)
      .map((o) => o.numeroMesa!)
      .toSet();

  Future<void> _crear() async {
    if (_tipoSeleccionado == null) return;
    if (_tipoSeleccionado == 'mesa' && _mesaSeleccionada == null) return;
    setState(() => _cargando = true);
    try {
      await widget.onCrear(
        _tipoSeleccionado!,
        _mesaSeleccionada,
        _nombreCtrl.text.trim(),
        _telefonoCtrl.text.trim(),
        _direccionCtrl.text.trim(),
        double.tryParse(_deliveryCtrl.text.trim()),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva Orden',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (_tipoSeleccionado == null) ...[
                _buildTipoSelector(),
              ] else ...[
                _buildFormulario(),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => setState(() {
                                _tipoSeleccionado = null;
                                _mesaSeleccionada = null;
                              }),
                      child: const Text('Atrás'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _cargando ? null : _crear,
                      child: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Crear Orden'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoSelector() {
    final tipos = <_TipoInfo>[
      if (widget.esRestaurante)
        const _TipoInfo(
            'mesa', 'Atención en Mesa', Icons.table_restaurant, Colors.purple),
      const _TipoInfo(
          'retiro', 'Retiro en Local', Icons.store_outlined, Colors.blue),
      const _TipoInfo(
          'domicilio', 'Domicilio', Icons.delivery_dining, Colors.orange),
      const _TipoInfo(
          'rapida', 'Venta Rápida', Icons.flash_on_rounded, Colors.teal),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tipos
          .map((t) => _TipoTile(
                tipo: t,
                onTap: () async {
                  if (t.value == 'rapida') {
                    setState(() => _cargando = true);
                    try {
                      await widget.onCrear(
                          'rapida', null, null, null, null, null);
                    } finally {
                      if (mounted) setState(() => _cargando = false);
                    }
                  } else {
                    setState(() => _tipoSeleccionado = t.value);
                  }
                },
              ))
          .toList(),
    );
  }

  Widget _buildFormulario() {
    if (_tipoSeleccionado == 'mesa') {
      final ocupadas = _mesasOcupadas;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecciona una mesa:',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 80,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 20,
              itemBuilder: (_, i) {
                final num = i + 1;
                final ocupada = ocupadas.contains(num);
                final seleccionada = _mesaSeleccionada == num;
                return InkWell(
                  onTap: ocupada
                      ? null
                      : () {
                          setState(() => _mesaSeleccionada = num);
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ocupada
                          ? Colors.red.shade50
                          : seleccionada
                              ? AppColors.primary
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ocupada
                            ? Colors.red.shade200
                            : seleccionada
                                ? AppColors.primary
                                : Colors.grey.shade300,
                        width: seleccionada ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_restaurant,
                            size: 20,
                            color: ocupada
                                ? Colors.red.shade300
                                : seleccionada
                                    ? Colors.white
                                    : Colors.grey.shade600),
                        const SizedBox(height: 2),
                        Text('$num',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ocupada
                                    ? Colors.red.shade400
                                    : seleccionada
                                        ? Colors.white
                                        : Colors.grey.shade700)),
                        if (ocupada)
                          const Text('Ocup.',
                              style: TextStyle(fontSize: 9, color: Colors.red)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextField(
          controller: _nombreCtrl,
          decoration: InputDecoration(
            labelText: _tipoSeleccionado == 'domicilio'
                ? 'Nombre cliente *'
                : 'Nombre (opcional)',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefonoCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono (opcional)',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_tipoSeleccionado == 'domicilio') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _direccionCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Dirección de entrega *',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deliveryCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Costo de delivery (\$)',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _TipoInfo {
  const _TipoInfo(this.value, this.label, this.icon, this.color);
  final String value, label;
  final IconData icon;
  final Color color;
}

class _TipoTile extends StatelessWidget {
  const _TipoTile({required this.tipo, required this.onTap});
  final _TipoInfo tipo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tipo.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tipo.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tipo.icon, color: tipo.color, size: 32),
            const SizedBox(height: 8),
            Text(tipo.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tipo.color)),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo Pagar ────────────────────────────────────────────────────────

typedef _OnPagar = Future<void> Function(String metodoPago, String? obs);

class _PagarDialog extends StatefulWidget {
  const _PagarDialog(
      {required this.orden, required this.total, required this.onPagar});
  final Orden orden;
  final double total;
  final _OnPagar onPagar;

  @override
  State<_PagarDialog> createState() => _PagarDialogState();
}

class _PagarDialogState extends State<_PagarDialog> {
  String _metodo = 'efectivo';
  final _recibidoCtrl = TextEditingController();
  bool _cargando = false;

  double get _recibido => double.tryParse(_recibidoCtrl.text) ?? 0;
  double get _cambio => _recibido - widget.total;

  @override
  void dispose() {
    _recibidoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orden = widget.orden;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registrar Pago',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(orden.etiqueta,
                  style: TextStyle(color: Colors.grey.shade600)),
              const Divider(height: 24),
              // Items resumen
              ...orden.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                            '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(1)}x ',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                        Expanded(
                            child: Text(item.nombre,
                                style: const TextStyle(fontSize: 13))),
                        Text(_fmt.format(item.subtotal),
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
              if (orden.costoDelivery > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Expanded(
                          child: Text('Delivery',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.orange))),
                      Text(_fmt.format(orden.costoDelivery),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.orange)),
                    ],
                  ),
                ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_fmt.format(widget.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              // Método de pago
              const Text('Método de pago:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _MetodoChip('efectivo', 'Efectivo', Icons.payments_outlined,
                      _metodo, (v) => setState(() => _metodo = v)),
                  _MetodoChip('tarjeta', 'Tarjeta', Icons.credit_card, _metodo,
                      (v) => setState(() => _metodo = v)),
                  _MetodoChip(
                      'transferencia',
                      'Transferencia',
                      Icons.account_balance_outlined,
                      _metodo,
                      (v) => setState(() => _metodo = v)),
                ],
              ),
              // Si efectivo: campo recibido + cambio
              if (_metodo == 'efectivo') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _recibidoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo recibido (\$)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (_recibido >= widget.total && _recibidoCtrl.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cambio:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success)),
                          Text(_fmt.format(_cambio),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cargando
                      ? null
                      : () async {
                          setState(() => _cargando = true);
                          try {
                            await widget.onPagar(_metodo, null);
                          } finally {
                            if (mounted) setState(() => _cargando = false);
                          }
                        },
                  icon: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_cargando ? 'Registrando...' : 'Confirmar Pago'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed:
                      _cargando ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetodoChip extends StatelessWidget {
  const _MetodoChip(
      this.value, this.label, this.icon, this.selected, this.onSelected);
  final String value, label, selected;
  final IconData icon;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.black87, fontSize: 12),
      checkmarkColor: AppColors.primary,
    );
  }
}
