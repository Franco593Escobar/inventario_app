// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/models/proveedor.dart';
import 'package:inventario_app/data/models/seccion.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/data/repositories/proveedor_repository.dart';
import 'package:inventario_app/data/repositories/seccion_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/screens/proveedores/proveedores_screen.dart';
import 'package:inventario_app/presentation/screens/secciones/secciones_screen.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class ProductsManagementScreen extends StatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  State<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState extends State<ProductsManagementScreen> {
  final ProductRepository _repository = ProductRepository();
  final ProveedorRepository _proveedorRepository = ProveedorRepository();
  final SeccionRepository _seccionRepository = SeccionRepository();
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'todos';
  String _selectedStock = 'todos';
  List<Product> _cachedProducts = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatFirestoreError(Object error, String action) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No se pudo $action: Firestore denegó la escritura.';
        case 'unavailable':
          return 'No se pudo $action: servicio no disponible.';
        default:
          return 'No se pudo $action: ${error.message ?? error.code}';
      }
    }
    return 'No se pudo $action. Detalle: $error';
  }

  void _showFeedback(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchController.text.trim().toLowerCase();
    return products.where((p) {
      final matchQuery = query.isEmpty ||
          p.nombre.toLowerCase().contains(query) ||
          p.codigo.toLowerCase().contains(query) ||
          (p.seccionNombre ?? '').toLowerCase().contains(query) ||
          (p.proveedorNombre ?? '').toLowerCase().contains(query);
      final matchStatus = _selectedStatus == 'todos' ||
          (_selectedStatus == 'activos' && p.activo) ||
          (_selectedStatus == 'inactivos' && !p.activo);
      final matchStock = _selectedStock == 'todos' ||
          (_selectedStock == 'agotado' && p.stock <= 0) ||
          (_selectedStock == 'bajo' &&
              p.stock > 0 &&
              p.stock <= p.stockMinimo) ||
          (_selectedStock == 'disponible' && p.stock > p.stockMinimo);
      return matchQuery && matchStatus && matchStock;
    }).toList();
  }

  Future<void> _openProductForm([Product? product]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final auditor = auth.nombreUsuario;
    final tenantId = auth.tenantId;

    // Cargar proveedores y secciones
    List<Proveedor> proveedores = [];
    List<Seccion> secciones = [];
    try {
      proveedores = await _proveedorRepository.watchByTenant(tenantId).first;
      secciones = await _seccionRepository.watchByTenant(tenantId).first;
    } catch (_) {}

    final codigoCtrl = TextEditingController(text: product?.codigo ?? '');
    final nombreCtrl = TextEditingController(text: product?.nombre ?? '');
    final costoCtrl = TextEditingController(
        text: product?.costo.toStringAsFixed(2) ?? '0.00');
    final precioCtrl = TextEditingController(
        text: product?.precioVenta.toStringAsFixed(2) ?? '0.00');
    final stockCtrl =
        TextEditingController(text: product?.stock.toString() ?? '0');
    final stockMinCtrl =
        TextEditingController(text: product?.stockMinimo.toString() ?? '0');
    final posCtrl = TextEditingController(
        text: product?.posicionPantalla.toString() ?? '0');
    final descCtrl = TextEditingController(text: product?.descripcion ?? '');

    final kImpuestosStd = ['IVA 0%', 'IVA 12%', 'IVA 15%', 'Exento', 'No objeto'];
    final rawImpuesto = product?.impuesto ?? 'IVA 15%';
    String impuesto =
        kImpuestosStd.contains(rawImpuesto) ? rawImpuesto : 'Personalizado...';
    final impuestoCustomCtrl = TextEditingController(
        text: kImpuestosStd.contains(rawImpuesto) ? '' : rawImpuesto);
    String vendidoEn = product?.vendidoEn ?? 'unidades';
    bool mostrarEnVentas = product?.mostrarEnVentas ?? true;
    bool mostrarEnPedidos = product?.mostrarEnPedidos ?? false;
    bool activo = product?.activo ?? true;
    String? proveedorId = product?.proveedorId;
    String? proveedorNombre = product?.proveedorNombre;
    String? seccionId = product?.seccionId;
    String? seccionNombre = product?.seccionNombre;
    List<String> ubicacion = List<String>.from(product?.ubicacion ?? []);
    List<String> codigosAdicionales =
        List<String>.from(product?.codigosAdicionales ?? []);
    String? imgBase64 = product?.imagenBase64;
    String? imgFormato = product?.imagenFormato;

    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? submitError;

    // Tab controller para "Últimas Compras" y "Códigos adicionales"
    int tabIndex = 0;
    final codigoAdCtrl = TextEditingController();

    Future<void> pickImage(StateSetter set) async {
      final upload = html.FileUploadInputElement()
        ..accept = 'image/jpeg,image/png,image/webp';
      upload.click();
      await upload.onChange.first;
      final file = upload.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;
      final result = reader.result as String;
      final comma = result.indexOf(',');
      final b64 = result.substring(comma + 1);
      final ext = file.name.split('.').last.toLowerCase();
      set(() {
        imgBase64 = b64;
        imgFormato = ext;
      });
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (ctx, setDS) {
          final isWide = MediaQuery.of(ctx).size.width > 960;

          Widget leftColumn() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Código de barras
                  _formRow(
                    label: 'CÓDIGO DE BARRAS',
                    child: TextFormField(
                      controller: codigoCtrl,
                      autofocus: product == null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '7890...',
                        prefixIcon: Icon(Icons.qr_code_scanner),
                      ),
                    ),
                  ),
                  _formRow(
                    label: 'NOMBRE *',
                    child: TextFormField(
                      controller: nombreCtrl,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                  ),
                  // Proveedor
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('PROVEEDOR',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Gestionar'),
                            onPressed: () async {
                              await Navigator.of(ctx, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProveedoresScreen(),
                                  fullscreenDialog: true,
                                ),
                              );
                              final lista = await _proveedorRepository
                                  .watchByTenant(tenantId)
                                  .first;
                              setDS(() => proveedores = lista);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: proveedorId,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('— Sin proveedor —')),
                          ...proveedores.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.nombre),
                              )),
                        ],
                        onChanged: (v) {
                          setDS(() {
                            proveedorId = v;
                            proveedorNombre = v == null
                                ? null
                                : proveedores
                                    .firstWhere((p) => p.id == v)
                                    .nombre;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  // Impuesto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IMPUESTO',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: impuesto,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'IVA 0%', child: Text('IVA 0%')),
                          DropdownMenuItem(
                              value: 'IVA 12%', child: Text('IVA 12%')),
                          DropdownMenuItem(
                              value: 'IVA 15%', child: Text('IVA 15%')),
                          DropdownMenuItem(
                              value: 'Exento', child: Text('Exento')),
                          DropdownMenuItem(
                              value: 'No objeto', child: Text('No objeto')),
                          DropdownMenuItem(
                              value: 'Personalizado...',
                              child: Text('Personalizado...')),
                        ],
                        onChanged: (v) =>
                            setDS(() => impuesto = v ?? 'IVA 15%'),
                      ),
                      if (impuesto == 'Personalizado...') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: impuestoCustomCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Porcentaje personalizado',
                            hintText: 'ej. 8',
                            suffixText: '%',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                  // Costo, Stock, StockMin en fila
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _numField(costoCtrl, 'COSTO', decimal: true),
                      _numField(stockCtrl, 'STOCK'),
                      _numField(stockMinCtrl, 'STOCK MÍN.'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Precio de venta + Calcular
                  Row(
                    children: [
                      Expanded(
                        child: _formRow(
                          label: 'PRECIO DE VENTA (con impuesto)',
                          child: TextFormField(
                            controller: precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                border: OutlineInputBorder()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: OutlinedButton(
                          onPressed: () {
                            final costo =
                                double.tryParse(costoCtrl.text.trim()) ?? 0;
                            double factor = 1.0;
                            if (impuesto == 'IVA 15%') factor = 1.15;
                            if (impuesto == 'IVA 12%') factor = 1.12;
                            if (impuesto == 'Personalizado...') {
                              final pct = double.tryParse(
                                      impuestoCustomCtrl.text
                                          .trim()
                                          .replaceAll('%', '')) ??
                                  0;
                              factor = 1.0 + (pct / 100);
                            }
                            setDS(() => precioCtrl.text =
                                (costo * factor).toStringAsFixed(2));
                          },
                          child: const Text('Calcular'),
                        ),
                      ),
                    ],
                  ),
                  // Ubicaciones checkboxes (dinámico por secciones / hardcoded default)
                  const SizedBox(height: 12),
                  const Text('PREPARADO EN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['COCINA', 'BARRA', 'FRIO', 'OTROS']
                        .map((loc) => FilterChip(
                              label: Text(loc),
                              selected: ubicacion.contains(loc),
                              onSelected: (v) {
                                setDS(() {
                                  if (v) {
                                    ubicacion.add(loc);
                                  } else {
                                    ubicacion.remove(loc);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  // Sección selector
                  Row(
                    children: [
                      const Text('SECCIÓN',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Gestionar'),
                        onPressed: () async {
                          await Navigator.of(ctx, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const SeccionesScreen(),
                              fullscreenDialog: true,
                            ),
                          );
                          final lista = await _seccionRepository
                              .watchByTenant(tenantId)
                              .first;
                          setDS(() => secciones = lista);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 80,
                    child: secciones.isEmpty
                        ? const Text(
                            'Sin secciones. Crea secciones primero.',
                            style: TextStyle(color: Colors.grey),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: secciones.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final sec = secciones[i];
                              final sel = seccionId == sec.id;
                              return GestureDetector(
                                onTap: () => setDS(() {
                                  if (sel) {
                                    seccionId = null;
                                    seccionNombre = null;
                                  } else {
                                    seccionId = sec.id;
                                    seccionNombre = sec.nombre;
                                  }
                                }),
                                child: Container(
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.primary
                                          : const Color(0xFFDDE3EF),
                                      width: sel ? 2.5 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: sec.imagenBase64 != null
                                            ? Image.memory(
                                                base64Decode(sec.imagenBase64!),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                            : Container(
                                                color: const Color(0xFFEEF2FA),
                                                child: const Icon(
                                                    Icons.image_outlined,
                                                    size: 20,
                                                    color: Colors.grey),
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: Text(
                                          sec.nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : FontWeight.normal),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (seccionNombre != null) ...[
                    const SizedBox(height: 4),
                    Text('Sección: $seccionNombre',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary)),
                  ],
                  const SizedBox(height: 12),
                  // vendido en
                  const Text('ESTE PRODUCTO SE VENDE EN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'unidades', label: Text('Unidades')),
                      ButtonSegment(
                          value: 'decimales', label: Text('Decimales')),
                    ],
                    selected: {vendidoEn},
                    onSelectionChanged: (v) => setDS(() => vendidoEn = v.first),
                  ),
                  const SizedBox(height: 12),
                  // checkboxes mostrar
                  Row(
                    children: [
                      Checkbox(
                        value: mostrarEnVentas,
                        onChanged: (v) =>
                            setDS(() => mostrarEnVentas = v ?? true),
                      ),
                      const Text('Mostrar en Ventas'),
                      const SizedBox(width: 16),
                      Checkbox(
                        value: mostrarEnPedidos,
                        onChanged: (v) =>
                            setDS(() => mostrarEnPedidos = v ?? false),
                      ),
                      const Text('Mostrar en Pedidos'),
                    ],
                  ),
                  // posición pantalla
                  SizedBox(
                    width: 150,
                    child: TextFormField(
                      controller: posCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'POSICIÓN EN PANTALLA',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Producto activo'),
                    value: activo,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setDS(() => activo = v),
                  ),
                ],
              );

          Widget rightColumn() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IMAGEN DEL PRODUCTO',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => pickImage(setDS),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE3EF)),
                        color: const Color(0xFFF7F9FC),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: imgBase64 != null
                          ? Image.memory(base64Decode(imgBase64!),
                              fit: BoxFit.contain)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Clic para subir imagen',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                  if (imgBase64 != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setDS(() {
                        imgBase64 = null;
                        imgFormato = null;
                      }),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 16),
                      label: const Text('Quitar imagen',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('DESCRIPCIÓN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Descripción del producto...'),
                  ),
                ],
              );

          Widget bottomTabs() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Códigos adicionales'),
                      Tab(text: 'Últimas Compras'),
                    ],
                    onTap: (i) => setDS(() => tabIndex = i),
                  ),
                  if (tabIndex == 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codigoAdCtrl,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Código adicional',
                            ),
                            onFieldSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setDS(() {
                                  codigosAdicionales.add(v.trim());
                                  codigoAdCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final v = codigoAdCtrl.text.trim();
                            if (v.isNotEmpty) {
                              setDS(() {
                                codigosAdicionales.add(v);
                                codigoAdCtrl.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: codigosAdicionales
                          .map((c) => Chip(
                                label: Text(c),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () =>
                                    setDS(() => codigosAdicionales.remove(c)),
                              ))
                          .toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Historial de compras disponible próximamente.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              );

          return DefaultTabController(
            length: 2,
            child: Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Scaffold(
                  backgroundColor: Colors.white,
                  appBar: AppBar(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    title: Text(
                        product == null ? 'Nuevo Producto' : 'Editar Producto'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                setDS(() {
                                  isSubmitting = true;
                                  submitError = null;
                                });
                                final draft = Product(
                                  id: product?.id ?? '',
                                  tenantId: product?.tenantId ?? tenantId,
                                  codigo: codigoCtrl.text.trim(),
                                  nombre: nombreCtrl.text.trim(),
                                  proveedorId: proveedorId,
                                  proveedorNombre: proveedorNombre,
                                  impuesto: impuesto == 'Personalizado...'
                                      ? impuestoCustomCtrl.text.trim()
                                      : impuesto,
                                  costo:
                                      double.tryParse(costoCtrl.text.trim()) ??
                                          0,
                                  stock:
                                      int.tryParse(stockCtrl.text.trim()) ?? 0,
                                  stockMinimo:
                                      int.tryParse(stockMinCtrl.text.trim()) ??
                                          0,
                                  precioVenta:
                                      double.tryParse(precioCtrl.text.trim()) ??
                                          0,
                                  ubicacion: ubicacion,
                                  seccionId: seccionId,
                                  seccionNombre: seccionNombre,
                                  vendidoEn: vendidoEn,
                                  mostrarEnVentas: mostrarEnVentas,
                                  posicionPantalla:
                                      int.tryParse(posCtrl.text.trim()) ?? 0,
                                  mostrarEnPedidos: mostrarEnPedidos,
                                  imagenBase64: imgBase64,
                                  imagenFormato: imgFormato,
                                  descripcion: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  codigosAdicionales: codigosAdicionales,
                                  activo: activo,
                                  fechaCreacion:
                                      product?.fechaCreacion ?? DateTime.now(),
                                  creadoPor: product?.creadoPor ?? auditor,
                                  modificadoPor: auditor,
                                );
                                try {
                                  if (product == null) {
                                    await _repository.createProduct(draft);
                                  } else {
                                    await _repository.updateProduct(draft);
                                  }
                                } catch (e) {
                                  setDS(() {
                                    isSubmitting = false;
                                    submitError = _formatFirestoreError(
                                        e,
                                        product == null
                                            ? 'crear'
                                            : 'actualizar');
                                  });
                                  return;
                                }
                                if (!dialogContext.mounted) return;
                                Navigator.of(dialogContext).pop(true);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Guardar'),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  body: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: leftColumn()),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 2, child: rightColumn()),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      leftColumn(),
                                      const SizedBox(height: 16),
                                      rightColumn(),
                                    ],
                                  ),
                          ),
                        ),
                        // Bottom tabs
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: bottomTabs(),
                        ),
                        if (submitError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(submitError!,
                                  style: TextStyle(color: Colors.red.shade900)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      codigoCtrl.dispose();
      nombreCtrl.dispose();
      costoCtrl.dispose();
      precioCtrl.dispose();
      stockCtrl.dispose();
      stockMinCtrl.dispose();
      posCtrl.dispose();
      descCtrl.dispose();
      codigoAdCtrl.dispose();
      impuestoCustomCtrl.dispose();
    });

    if (saved == true && mounted) {
      _showFeedback(
        product == null
            ? 'Producto creado correctamente'
            : 'Producto actualizado correctamente',
        color: AppColors.success,
      );
    }
  }

  static Widget _formRow({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        child,
        const SizedBox(height: 12),
      ],
    );
  }

  static Widget _numField(
    TextEditingController ctrl,
    String label, {
    bool decimal = false,
  }) {
    return SizedBox(
      width: 130,
      child: TextFormField(
        controller: ctrl,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
            '¿Seguro que deseas eliminar "${product.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteProduct(product.id);
    if (!mounted) return;
    _showFeedback('Producto eliminado', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = auth.tenantId;

    return StreamBuilder<List<Product>>(
      stream: _repository.watchByTenant(tenantId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snapshot.error}',
                      textAlign: TextAlign.center)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!;
        if (_cachedProducts != products) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _cachedProducts = products);
          });
        }
        final filtered = _filterProducts(products);
        final activos = products.where((p) => p.activo).length;
        final stockBajo = products
            .where((p) => p.activo && p.stock <= p.stockMinimo && p.stock > 0)
            .length;
        final agotados = products.where((p) => p.stock <= 0).length;

        return LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 980;

          return AdminModuleShell(
            title: 'Productos',
            subtitle: 'Gestiona el catálogo de productos de tu negocio.',
            metricChips: [
              AdminMetricChip(
                  label: 'Total', value: products.length.toString()),
              AdminMetricChip(
                  label: 'Activos',
                  value: activos.toString(),
                  color: AppColors.success),
              AdminMetricChip(
                  label: 'Stock bajo',
                  value: stockBajo.toString(),
                  color: Colors.orange),
              AdminMetricChip(
                  label: 'Agotados',
                  value: agotados.toString(),
                  color: AppColors.error),
            ],
            primaryAction: AdminPrimaryButton(
              label: 'Nuevo',
              icon: Icons.add,
              onPressed: _openProductForm,
            ),
            filters: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isWide ? 360 : double.infinity,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFF7F9FC),
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nombre, código o sección',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F9FC),
                        border: OutlineInputBorder(),
                        labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(
                          value: 'activos', child: Text('Activos')),
                      DropdownMenuItem(
                          value: 'inactivos', child: Text('Inactivos')),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedStatus = v ?? 'todos'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStock,
                    decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F9FC),
                        border: OutlineInputBorder(),
                        labelText: 'Stock'),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(
                          value: 'agotado', child: Text('Agotado')),
                      DropdownMenuItem(value: 'bajo', child: Text('Bajo')),
                      DropdownMenuItem(
                          value: 'disponible', child: Text('Disponible')),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedStock = v ?? 'todos'),
                  ),
                ),
              ],
            ),
            content: products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay productos registrados.'),
                    ),
                  )
                : filtered.isEmpty
                    ? const Center(
                        child: Text('Sin resultados para el filtro.'))
                    : AdminTableCard(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('IMAGEN')),
                              DataColumn(label: Text('CÓDIGO')),
                              DataColumn(label: Text('NOMBRE')),
                              DataColumn(label: Text('SECCIÓN')),
                              DataColumn(label: Text('PRECIO')),
                              DataColumn(label: Text('STOCK')),
                              DataColumn(label: Text('ESTADO')),
                              DataColumn(label: Text('ACCIONES')),
                            ],
                            rows: filtered.map((p) {
                              final stockColor = p.stock <= 0
                                  ? Colors.red
                                  : p.stock <= p.stockMinimo
                                      ? Colors.orange
                                      : AppColors.success;
                              return DataRow(cells: [
                                DataCell(
                                  p.imagenBase64 != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.memory(
                                            base64Decode(p.imagenBase64!),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FA),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                              Icons.image_outlined,
                                              size: 20,
                                              color: Colors.grey),
                                        ),
                                ),
                                DataCell(Text(p.codigo.isEmpty ? '—' : p.codigo,
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12))),
                                DataCell(Text(p.nombre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text(p.seccionNombre ?? '—')),
                                DataCell(Text(
                                    '\$${p.precioVenta.toStringAsFixed(2)}')),
                                DataCell(Text(
                                  p.stock.toString(),
                                  style: TextStyle(
                                      color: stockColor,
                                      fontWeight: FontWeight.w600),
                                )),
                                DataCell(Switch.adaptive(
                                  value: p.activo,
                                  activeColor: AppColors.success,
                                  onChanged: (v) => _repository
                                      .updateProduct(p.copyWith(activo: v)),
                                )),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      tooltip: 'Editar',
                                      onPressed: () => _openProductForm(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      tooltip: 'Eliminar',
                                      onPressed: () => _deleteProduct(p),
                                    ),
                                  ],
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          );
        });
      },
    );
  }
}
