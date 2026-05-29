import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/orden.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/models/salon.dart';
import 'package:inventario_app/data/repositories/orden_repository.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/data/repositories/salon_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/screens/ventas/cobrar_screen.dart';

enum _FacturacionView { entrada, nuevaVenta, ventasPendientes, pos }

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
  final _salonRepo = SalonRepository();
  final _busquedaCtrl = TextEditingController();

  // ── Vista actual ──────────────────────────────────────────────────────────
  _FacturacionView _view = _FacturacionView.entrada;

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
      _view = _FacturacionView.pos;
    });
  }

  // ── Navegación entre vistas ────────────────────────────────────────────────
  void _irAEntrada() => setState(() {
        _view = _FacturacionView.entrada;
        _ordenSeleccionada = null;
        _carritoLocal = [];
      });

  void _irANuevaVenta() => setState(() => _view = _FacturacionView.nuevaVenta);

  void _irAVentasPendientes() =>
      setState(() => _view = _FacturacionView.ventasPendientes);

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
    return switch (_view) {
      _FacturacionView.entrada => _buildEntrada(),
      _FacturacionView.nuevaVenta => _buildNuevaVenta(),
      _FacturacionView.ventasPendientes => _buildVentasPendientes(),
      _FacturacionView.pos => _buildPOSView(),
    };
  }

  // ─── Vista: Entrada (2 botones) ───────────────────────────────────────────

  Widget _buildEntrada() {
    final auth = context.read<AuthProvider>();
    final brandColor = auth.marcaPrimaryColor;
    return Container(
      color: const Color(0xFFF2F5FA),
      child: Column(
        children: [
          Container(
            color: const Color(0xFF171B21),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Colors.white54, size: 20),
                const SizedBox(width: 10),
                const Text('Punto de Venta',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.point_of_sale_outlined,
                      size: 72, color: brandColor.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  const Text('¿Qué deseas hacer?',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2035))),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EntradaButton(
                        icon: Icons.add_circle_outline,
                        label: 'Nueva\nVenta',
                        color: brandColor,
                        onTap: _irANuevaVenta,
                      ),
                      const SizedBox(width: 24),
                      _EntradaButton(
                        icon: Icons.pending_actions,
                        label: 'Ventas\nPendientes',
                        color: Colors.orange,
                        onTap: _irAVentasPendientes,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Vista: Nueva Venta ───────────────────────────────────────────────────

  Widget _buildNuevaVenta() {
    final auth = context.read<AuthProvider>();
    if (!_esRestaurante) {
      return _buildNuevaVentaRapida(auth);
    }
    return _buildSalonesMesas(auth);
  }

  Widget _buildNuevaVentaRapida(AuthProvider auth) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171B21),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
            onPressed: _irAEntrada, icon: const Icon(Icons.arrow_back)),
        title: const Text('Nueva Venta'),
      ),
      body: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _TipoVentaCard(
              icon: Icons.bolt,
              label: 'Venta Rápida',
              descripcion: 'Sin datos de cliente ni mesa',
              color: AppColors.primary,
              onTap: () => _crearYAbrirOrden('rapida'),
            ),
            _TipoVentaCard(
              icon: Icons.shopping_bag_outlined,
              label: 'Retiro',
              descripcion: 'El cliente retira el pedido',
              color: Colors.teal,
              onTap: () => _crearYAbrirOrden('retiro'),
            ),
            _TipoVentaCard(
              icon: Icons.delivery_dining,
              label: 'Domicilio',
              descripcion: 'Envío a domicilio',
              color: Colors.deepOrange,
              onTap: () => _crearYAbrirOrden('domicilio'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearYAbrirOrden(String tipo) async {
    final auth = context.read<AuthProvider>();
    final nueva = Orden(
      id: '',
      tenantId: auth.tenantId,
      tipo: tipo,
      items: const [],
      estado: 'abierta',
      vendedor: auth.loginUsername,
      fechaCreacion: DateTime.now(),
    );
    final creada = await _ordenRepo.create(nueva);
    _seleccionarOrden(creada);
  }

  Future<void> _crearYAbrirOrdenMesa(Salon salon, Mesa mesa) async {
    final auth = context.read<AuthProvider>();
    final nueva = Orden(
      id: '',
      tenantId: auth.tenantId,
      tipo: 'mesa',
      items: const [],
      estado: 'abierta',
      vendedor: auth.loginUsername,
      fechaCreacion: DateTime.now(),
      numeroMesa: mesa.numero,
      salonId: salon.id,
      salonNombre: salon.nombre,
    );
    final creada = await _ordenRepo.create(nueva);
    _seleccionarOrden(creada);
  }

  Widget _buildSalonesMesas(AuthProvider auth) {
    return StreamBuilder<List<Salon>>(
      stream: _salonRepo.watchByTenant(auth.tenantId),
      builder: (context, snapSalones) {
        final salones = snapSalones.data ?? [];
        return Scaffold(
          backgroundColor: const Color(0xFFF2F5FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF171B21),
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: IconButton(
                onPressed: _irAEntrada, icon: const Icon(Icons.arrow_back)),
            title: const Text('Seleccionar Mesa'),
            actions: [
              TextButton.icon(
                onPressed: () => _crearYAbrirOrden('rapida'),
                icon: const Icon(Icons.bolt, color: Colors.white70),
                label: const Text('Venta Rápida',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          body: salones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_restaurant,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No hay salones configurados',
                          style:
                              TextStyle(fontSize: 16, color: Colors.black45)),
                      const SizedBox(height: 8),
                      const Text('Ve a Configuración → Salones para crearlos',
                          style: TextStyle(color: Colors.black38)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _crearYAbrirOrden('rapida'),
                        icon: const Icon(Icons.bolt),
                        label: const Text('Continuar como Venta Rápida'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                )
              : StreamBuilder<List<Orden>>(
                  stream: _ordenRepo.watchAbiertas(auth.tenantId),
                  builder: (context, snapOrdenes) {
                    final ordenesAbiertas = snapOrdenes.data ?? [];
                    final mesasOcupadas = <String>{};
                    for (final o in ordenesAbiertas) {
                      if (o.salonId != null && o.numeroMesa != null) {
                        mesasOcupadas.add('${o.salonId}_${o.numeroMesa}');
                      }
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: salones.length,
                      itemBuilder: (ctx, i) {
                        final salon = salones[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(salon.nombre,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                if (salon.descripcion.isNotEmpty)
                                  Text(salon.descripcion,
                                      style: const TextStyle(
                                          color: Colors.black45, fontSize: 12)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: salon.mesas
                                      .where((m) => m.activa)
                                      .map((mesa) {
                                    final clave = '${salon.id}_${mesa.numero}';
                                    final ocupada =
                                        mesasOcupadas.contains(clave);
                                    return _MesaChipPOS(
                                      mesa: mesa,
                                      ocupada: ocupada,
                                      onTap: ocupada
                                          ? null
                                          : () => _crearYAbrirOrdenMesa(
                                              salon, mesa),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  // ─── Vista: Ventas Pendientes ─────────────────────────────────────────────

  Widget _buildVentasPendientes() {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171B21),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
            onPressed: _irAEntrada, icon: const Icon(Icons.arrow_back)),
        title: const Text('Ventas Pendientes'),
        actions: [
          TextButton.icon(
            onPressed: _irANuevaVenta,
            icon: const Icon(Icons.add, color: Colors.white70),
            label: const Text('Nueva Venta',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: StreamBuilder<List<Orden>>(
        stream: _ordenRepo.watchAbiertas(auth.tenantId),
        builder: (context, snap) {
          final ordenes = snap.data ?? [];
          if (ordenes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 72, color: Colors.black26),
                  SizedBox(height: 12),
                  Text('No hay ventas pendientes',
                      style: TextStyle(color: Colors.black45, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ordenes.length,
            itemBuilder: (ctx, i) {
              final orden = ordenes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  onTap: () => _seleccionarOrden(orden),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      orden.tipo == 'mesa'
                          ? Icons.table_restaurant
                          : orden.tipo == 'domicilio'
                              ? Icons.delivery_dining
                              : Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(orden.etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${orden.items.length} ítems · ${_fmt.format(orden.total)} · ${_fmtFecha.format(orden.fechaCreacion)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ─── Vista: POS completo ──────────────────────────────────────────────────

  Widget _buildPOSView() {
    final auth = context.read<AuthProvider>();
    return Column(
      children: [
        _buildPOSTopBar(auth),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            if (c.maxWidth >= 860) {
              return Row(
                children: [
                  Expanded(
                      flex: 3,
                      child:
                          _buildCatalogo(auth.tenantId, _ordenSeleccionada!)),
                  Container(
                    width: 290,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(left: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: _buildCarritoPanel(_ordenSeleccionada!, auth),
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
                        _buildCatalogo(auth.tenantId, _ordenSeleccionada!),
                        _buildCarritoPanel(_ordenSeleccionada!, auth),
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

  Widget _buildPOSTopBar(AuthProvider auth) {
    final orden = _ordenSeleccionada;
    return Container(
      color: const Color(0xFF171B21),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (orden != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    orden.tipo == 'mesa'
                        ? Icons.table_restaurant
                        : Icons.receipt_outlined,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(orden.etiqueta,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _POSTopBtn(
                      icon: Icons.add_circle_outline,
                      label: 'Nueva',
                      onTap: _irANuevaVenta),
                  _POSTopBtn(
                      icon: Icons.pending_actions,
                      label: 'Pendientes',
                      onTap: _irAVentasPendientes),
                  _POSTopBtn(
                      icon: Icons.home_outlined,
                      label: 'Inicio',
                      onTap: _irAEntrada),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _totalLocal > 0 ? () => _abrirCobrar(auth) : null,
            icon: const Icon(Icons.payments_outlined, size: 16),
            label: const Text('COBRAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirCobrar(AuthProvider auth) async {
    await _guardarCarrito();
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CobrarScreen(
          orden: _ordenSeleccionada!.copyWith(items: _carritoLocal),
          tenantId: auth.tenantId,
          vendedor: auth.loginUsername,
          ordenRepo: _ordenRepo,
        ),
      ),
    );
    if (result == true) {
      _irAEntrada();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Venta registrada — ${_fmt.format(_totalLocal)}'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    }
  }

  Future<void> _guardarCarrito() async {
    if (_ordenSeleccionada == null) return;
    await _ordenRepo.updateItems(_ordenSeleccionada!.id, _carritoLocal);
    setState(() => _ordenSeleccionada =
        _ordenSeleccionada!.copyWith(items: _carritoLocal));
  }

  Future<void> _mostrarMenuMasOpciones(AuthProvider auth) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Más Opciones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.merge_type, color: AppColors.primary),
              title: const Text('Unir Pedido'),
              subtitle: const Text('Fusionar con otra orden abierta'),
              onTap: () {
                Navigator.pop(context);
                _mostrarUnirPedido(auth.tenantId);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.call_split_outlined, color: Colors.teal),
              title: const Text('Cobro Parcial'),
              subtitle: const Text('Dividir cuenta ítem por ítem'),
              onTap: () {
                Navigator.pop(context);
                _mostrarCobroParcial();
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.add_circle_outline, color: Colors.green),
              title: const Text('Ingreso de Efectivo'),
              onTap: () {
                Navigator.pop(context);
                _mostrarMovimientoCaja('ingreso', auth);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Egreso de Efectivo'),
              onTap: () {
                Navigator.pop(context);
                _mostrarMovimientoCaja('egreso', auth);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.orange),
              title: const Text('Limpiar Pedido'),
              onTap: () {
                Navigator.pop(context);
                _limpiarOrden();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _limpiarOrden() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpiar orden'),
        content: const Text('¿Eliminar todos los ítems?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _carritoLocal = []);
      await _guardarCarrito();
    }
  }

  Future<void> _mostrarUnirPedido(String tenantId) async {
    if (_ordenSeleccionada == null) return;
    await _guardarCarrito();
    await showDialog(
      context: context,
      builder: (_) => _UnirPedidoDialog(
        ordenActual: _ordenSeleccionada!,
        ordenRepo: _ordenRepo,
        tenantId: tenantId,
        onUnida: (ord) {
          setState(() {
            _ordenSeleccionada = ord;
            _carritoLocal = List.from(ord.items);
          });
        },
      ),
    );
  }

  Future<void> _mostrarCobroParcial() async {
    if (_ordenSeleccionada == null || _carritoLocal.isEmpty) return;
    await _guardarCarrito();
    await showDialog(
      context: context,
      builder: (_) => _CobroParcialDialog(
        orden: _ordenSeleccionada!.copyWith(items: _carritoLocal),
        ordenRepo: _ordenRepo,
        onPagada: _irAEntrada,
      ),
    );
  }

  Future<void> _mostrarMovimientoCaja(String tipo, AuthProvider auth) async {
    await showDialog(
      context: context,
      builder: (_) => _MovimientoCajaDialog(
        tipo: tipo,
        loginUsername: auth.loginUsername,
        tenantId: auth.tenantId,
      ),
    );
  }

  // ─── (Mantiene el antiguo flujo de toolbar inline como builder helper) ────

  Widget _buildToolbar_old(BuildContext context, String tenantId,
      String vendedor, List<Orden> todasOrdenes) {
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
              Row(
                children: [
                  // Botón "+" opciones
                  OutlinedButton(
                    onPressed: () => _mostrarMenuMasOpciones(auth),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        minimumSize: Size.zero),
                    child: const Icon(Icons.more_horiz, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _carritoLocal.isEmpty
                          ? null
                          : () => _abrirCobrar(auth),
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: Text('Cobrar ${_fmt.format(_totalLocal)}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
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

// ─── Widgets nuevos ────────────────────────────────────────────────────────────

class _EntradaButton extends StatelessWidget {
  const _EntradaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipoVentaCard extends StatelessWidget {
  const _TipoVentaCard({
    required this.icon,
    required this.label,
    required this.descripcion,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label, descripcion;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 4),
            Text(descripcion,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black45, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _MesaChipPOS extends StatelessWidget {
  const _MesaChipPOS({required this.mesa, required this.ocupada, this.onTap});
  final Mesa mesa;
  final bool ocupada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: ocupada ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: ocupada ? Colors.red.shade200 : Colors.green.shade300,
              width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant,
                size: 26, color: ocupada ? Colors.red : Colors.green),
            const SizedBox(height: 4),
            Text(mesa.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 11,
                    color:
                        ocupada ? Colors.red.shade700 : Colors.green.shade800,
                    fontWeight: FontWeight.bold)),
            if (ocupada)
              const Text('Ocupada',
                  style: TextStyle(fontSize: 9, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _POSTopBtn extends StatelessWidget {
  const _POSTopBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white60),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo Unir Pedido ──────────────────────────────────────────────────────

class _UnirPedidoDialog extends StatelessWidget {
  const _UnirPedidoDialog({
    required this.ordenActual,
    required this.ordenRepo,
    required this.tenantId,
    required this.onUnida,
  });
  final Orden ordenActual;
  final OrdenRepository ordenRepo;
  final String tenantId;
  final ValueChanged<Orden> onUnida;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unir Pedido'),
      content: SizedBox(
        width: 380,
        child: StreamBuilder<List<Orden>>(
          stream: ordenRepo.watchAbiertas(tenantId),
          builder: (ctx, snap) {
            final otras =
                (snap.data ?? []).where((o) => o.id != ordenActual.id).toList();
            if (otras.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No hay otras órdenes abiertas para unir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45)),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: otras
                  .map((o) => ListTile(
                        leading: const Icon(Icons.receipt_outlined),
                        title: Text(o.etiqueta),
                        subtitle: Text(
                            '${o.items.length} ítems · ${NumberFormat('\$#,##0.00', 'en_US').format(o.total)}'),
                        trailing: const Icon(Icons.merge_type,
                            color: AppColors.primary),
                        onTap: () async {
                          final merged =
                              List<OrdenItem>.from(ordenActual.items);
                          for (final item in o.items) {
                            final idx = merged.indexWhere(
                                (i) => i.productoId == item.productoId);
                            if (idx >= 0) {
                              merged[idx] = merged[idx].conCantidad(
                                  merged[idx].cantidad + item.cantidad);
                            } else {
                              merged.add(item);
                            }
                          }
                          await ordenRepo.updateItems(ordenActual.id, merged);
                          await ordenRepo.cancelar(o.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          onUnida(ordenActual.copyWith(items: merged));
                        },
                      ))
                  .toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}

// ─── Diálogo Cobro Parcial ────────────────────────────────────────────────────

class _CobroParcialDialog extends StatefulWidget {
  const _CobroParcialDialog({
    required this.orden,
    required this.ordenRepo,
    required this.onPagada,
  });
  final Orden orden;
  final OrdenRepository ordenRepo;
  final VoidCallback onPagada;

  @override
  State<_CobroParcialDialog> createState() => _CobroParcialDialogState();
}

class _CobroParcialDialogState extends State<_CobroParcialDialog> {
  int _numPersonas = 2;
  late List<Set<int>> _seleccionadas;

  @override
  void initState() {
    super.initState();
    _seleccionadas = List.generate(_numPersonas, (_) => <int>{});
  }

  double _totalPersona(int p) => _seleccionadas[p]
      .fold(0.0, (acc, i) => acc + widget.orden.items[i].subtotal);

  final _nf = NumberFormat('\$#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Cobro Parcial'),
          const Spacer(),
          IconButton(
            onPressed: _numPersonas < 8
                ? () => setState(() {
                      _numPersonas++;
                      _seleccionadas.add(<int>{});
                    })
                : null,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            tooltip: 'Agregar persona',
          ),
          Text('$_numPersonas pers.',
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 380,
        child: SingleChildScrollView(
          child: Table(
            columnWidths: {
              0: const FlexColumnWidth(3),
              for (int p = 0; p < _numPersonas; p++)
                p + 1: const FixedColumnWidth(72),
            },
            border: TableBorder.all(color: Colors.grey.shade200),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  const TableCell(
                      child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Ítem',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)))),
                  for (int p = 0; p < _numPersonas; p++)
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('P${p + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                ],
              ),
              for (int i = 0; i < widget.orden.items.length; i++)
                TableRow(children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${widget.orden.items[i].nombre} x${widget.orden.items[i].cantidad.toInt()} — ${_nf.format(widget.orden.items[i].subtotal)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  for (int p = 0; p < _numPersonas; p++)
                    TableCell(
                      child: Checkbox(
                        value: _seleccionadas[p].contains(i),
                        onChanged: (v) => setState(() {
                          for (final s in _seleccionadas) s.remove(i);
                          if (v == true) _seleccionadas[p].add(i);
                        }),
                      ),
                    ),
                ]),
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  const TableCell(
                      child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('TOTAL',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)))),
                  for (int p = 0; p < _numPersonas; p++)
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(_nf.format(_totalPersona(p)),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppColors.primary)),
                      ),
                    ),
                ],
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
          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
          onPressed: () async {
            final asignados = _seleccionadas.expand((s) => s).toSet();
            if (asignados.length < widget.orden.items.length) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Asigna todos los ítems primero')));
              return;
            }
            for (int p = 0; p < _numPersonas; p++) {
              if (_seleccionadas[p].isEmpty) continue;
              final items = _seleccionadas[p]
                  .map((idx) => widget.orden.items[idx])
                  .toList();
              await widget.ordenRepo.pagar(
                widget.orden.copyWith(items: items),
                'efectivo',
                observaciones: 'Cobro parcial Persona ${p + 1}',
              );
            }
            if (mounted) Navigator.pop(context);
            widget.onPagada();
          },
          child: const Text('Cobrar por separado'),
        ),
      ],
    );
  }
}

// ─── Diálogo Movimiento de Caja ───────────────────────────────────────────────

class _MovimientoCajaDialog extends StatefulWidget {
  const _MovimientoCajaDialog({
    required this.tipo,
    required this.loginUsername,
    required this.tenantId,
  });
  final String tipo, loginUsername, tenantId;

  @override
  State<_MovimientoCajaDialog> createState() => _MovimientoCajaDialogState();
}

class _MovimientoCajaDialogState extends State<_MovimientoCajaDialog> {
  final _passCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _showPass = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    if (_passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa la contraseña de administrador');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instanceFor(
          app: Firebase.app(), databaseURL: 'inventario-bdd');
      final snap = await db
          .collection('usuarios')
          .where('tenant_id', isEqualTo: widget.tenantId)
          .where('login_username', isEqualTo: widget.loginUsername)
          .where('password', isEqualTo: _passCtrl.text.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        setState(() => _error = 'Contraseña incorrecta o sin permisos');
        return;
      }
      await db.collection('movimientos_caja').add({
        'tenant_id': widget.tenantId,
        'tipo': widget.tipo,
        'monto': monto,
        'observaciones': _obsCtrl.text.trim(),
        'registrado_por': widget.loginUsername,
        'fecha': DateTime.now().toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esIngreso = widget.tipo == 'ingreso';
    return AlertDialog(
      title: Row(
        children: [
          Icon(esIngreso ? Icons.add_circle : Icons.remove_circle,
              color: esIngreso ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(esIngreso ? 'Ingreso de Efectivo' : 'Egreso de Efectivo'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto *',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: esIngreso ? Colors.green.shade50 : Colors.red.shade50,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsCtrl,
            decoration: const InputDecoration(
                labelText: 'Observación', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: !_showPass,
            decoration: InputDecoration(
              labelText: 'Contraseña Admin *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility,
                    size: 18),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _confirmar,
          style: FilledButton.styleFrom(
              backgroundColor: esIngreso ? Colors.green : Colors.red),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(esIngreso ? 'Registrar Ingreso' : 'Registrar Egreso'),
        ),
      ],
    );
  }
}
