import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class ProductsManagementScreen extends StatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  State<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState extends State<ProductsManagementScreen> {
  final ProductRepository _repository = ProductRepository();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'todas';
  String _selectedStock = 'todos';
  String _selectedStatus = 'todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatFirestoreError(Object error, String action) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No se pudo $action porque Firestore negó la escritura. Revisa las reglas de la colección productos.';
        case 'unavailable':
          return 'No se pudo $action porque el servicio no está disponible en este momento.';
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

    return products.where((product) {
      final matchesQuery = query.isEmpty ||
          product.nombre.toLowerCase().contains(query) ||
          product.categoria.toLowerCase().contains(query) ||
          (product.codigo ?? '').toLowerCase().contains(query) ||
          (product.descripcion ?? '').toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == 'todas' ||
          product.categoria.toLowerCase() == _selectedCategory;

      final matchesStatus = switch (_selectedStatus) {
        'activos' => product.activo,
        'inactivos' => !product.activo,
        _ => true,
      };

      final matchesStock = switch (_selectedStock) {
        'agotado' => product.stock <= 0,
        'bajo' => product.stock > 0 && product.stock <= 5,
        'disponible' => product.stock > 5,
        _ => true,
      };

      return matchesQuery && matchesCategory && matchesStatus && matchesStock;
    }).toList();
  }

  Future<void> _openProductForm([Product? product]) async {
    final nombreController = TextEditingController(text: product?.nombre ?? '');
    final codigoController = TextEditingController(text: product?.codigo ?? '');
    final categoriaController =
        TextEditingController(text: product?.categoria ?? 'general');
    final descripcionController =
        TextEditingController(text: product?.descripcion ?? '');
    final precioController =
        TextEditingController(text: product?.precio.toString() ?? '0');
    final stockController =
        TextEditingController(text: product?.stock.toString() ?? '0');
    bool activo = product?.activo ?? true;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? submitError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isWide = MediaQuery.of(context).size.width > 900;

            return AdminFormDialog(
              title: product == null ? 'Nuevo Producto' : 'Editar Producto',
              body: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: nombreController,
                            decoration: const InputDecoration(
                              labelText: 'NOMBRE *',
                              hintText: 'Nombre del producto',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Ingresa el nombre'
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: codigoController,
                            decoration: const InputDecoration(
                              labelText: 'CODIGO',
                              hintText: 'Codigo interno',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: categoriaController,
                            decoration: const InputDecoration(
                              labelText: 'CATEGORIA *',
                              hintText: 'Categoria',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Ingresa la categoria'
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: precioController,
                            decoration: const InputDecoration(
                              labelText: 'PRECIO *',
                              hintText: '0.00',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              final parsed = double.tryParse(value ?? '');
                              return parsed == null
                                  ? 'Ingresa un precio valido'
                                  : null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: stockController,
                            decoration: const InputDecoration(
                              labelText: 'STOCK *',
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              return parsed == null
                                  ? 'Ingresa un stock valido'
                                  : null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: descripcionController,
                            decoration: const InputDecoration(
                              labelText: 'DESCRIPCION',
                              hintText: 'Detalle del producto',
                            ),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Producto activo'),
                      value: activo,
                      onChanged: (value) {
                        setDialogState(() => activo = value);
                      },
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          submitError!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setDialogState(() {
                      isSubmitting = true;
                      submitError = null;
                    });

                    final draft = Product(
                      id: product?.id ?? '',
                      nombre: nombreController.text,
                      categoria: categoriaController.text,
                      precio: double.parse(precioController.text),
                      stock: int.parse(stockController.text),
                      activo: activo,
                      codigo: codigoController.text.isEmpty
                          ? null
                          : codigoController.text,
                      descripcion: descripcionController.text.isEmpty
                          ? null
                          : descripcionController.text,
                    );

                    try {
                      if (product == null) {
                        await _repository.createProduct(draft);
                      } else {
                        await _repository.updateProduct(draft);
                      }
                    } catch (error) {
                      setDialogState(() {
                        isSubmitting = false;
                        submitError = _formatFirestoreError(
                          error,
                          product == null
                              ? 'crear el producto'
                              : 'actualizar el producto',
                        );
                      });
                      return;
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    codigoController.dispose();
    categoriaController.dispose();
    descripcionController.dispose();
    precioController.dispose();
    stockController.dispose();

    if (saved == true && mounted) {
      _showFeedback(
        product == null
            ? 'Producto creado correctamente'
            : 'Producto actualizado correctamente',
        color: AppColors.success,
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que deseas eliminar ${product.nombre}? Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repository.deleteProduct(product.id);
    if (!mounted) return;
    _showFeedback('Producto eliminado correctamente', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _repository.watchProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar la lista de productos: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!;
        final filteredProducts = _filterProducts(products);
        final categories = products
            .map((product) => product.categoria.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final activeProducts =
            products.where((product) => product.activo).length;
        final lowStockProducts =
            products.where((product) => product.stock <= 5).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 980;

            return AdminModuleShell(
              title: 'Productos',
              subtitle:
                  'Mantén el catálogo con una interfaz administrativa más clara para web y tablet.',
              metricChips: [
                AdminMetricChip(
                  label: 'Productos',
                  value: products.length.toString(),
                ),
                AdminMetricChip(
                  label: 'Activos',
                  value: activeProducts.toString(),
                  color: AppColors.success,
                ),
                AdminMetricChip(
                  label: 'Stock bajo',
                  value: lowStockProducts.toString(),
                  color: AppColors.accent,
                ),
                AdminMetricChip(
                  label: 'Filtrados',
                  value: filteredProducts.length.toString(),
                ),
              ],
              primaryAction: AdminPrimaryButton(
                label: 'Nuevo',
                icon: Icons.add_box_outlined,
                onPressed: _openProductForm,
              ),
              filters: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isWide ? 320 : double.infinity,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F9FC),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar por nombre, código o categoría',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F9FC),
                        border: OutlineInputBorder(),
                        labelText: 'Categoría',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'todas',
                          child: Text('Todas'),
                        ),
                        ...categories.map(
                          (category) => DropdownMenuItem(
                            value: category.toLowerCase(),
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedCategory = value);
                      },
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
                        labelText: 'Estado',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'activos',
                          child: Text('Activos'),
                        ),
                        DropdownMenuItem(
                          value: 'inactivos',
                          child: Text('Inactivos'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedStatus = value);
                      },
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
                        labelText: 'Stock',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'agotado',
                          child: Text('Agotado'),
                        ),
                        DropdownMenuItem(
                          value: 'bajo',
                          child: Text('Bajo'),
                        ),
                        DropdownMenuItem(
                          value: 'disponible',
                          child: Text('Disponible'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedStock = value);
                      },
                    ),
                  ),
                  Text(
                    'Filtro por sucursal pendiente hasta que el modelo de producto incluya ese dato.',
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                ],
              ),
              content: products.isEmpty
                  ? const Center(
                      child: Text('No hay productos registrados todavía.'),
                    )
                  : filteredProducts.isEmpty
                      ? const Center(
                          child:
                              Text('No hay resultados para el filtro actual.'),
                        )
                      : AdminTableCard(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filteredProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _ProductRowCard(
                                product: product,
                                isWide: isWide,
                                onEdit: () => _openProductForm(product),
                                onDelete: () => _deleteProduct(product),
                              );
                            },
                          ),
                        ),
            );
          },
        );
      },
    );
  }
}

class _ProductRowCard extends StatelessWidget {
  const _ProductRowCard({
    required this.product,
    required this.isWide,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final bool isWide;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: isWide
            ? Row(
                children: [
                  Expanded(
                      flex: 3, child: _PrimaryProductCell(product: product)),
                  Expanded(flex: 2, child: Text(product.categoria)),
                  Expanded(
                    flex: 2,
                    child: Text('\$${product.precio.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ProductBadge(
                      label: 'Stock ${product.stock}',
                      color: product.stock <= 5
                          ? AppColors.accent
                          : AppColors.primary,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ProductBadge(
                      label: product.activo ? 'Activo' : 'Inactivo',
                      color:
                          product.activo ? AppColors.success : AppColors.error,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrimaryProductCell(product: product),
                  const SizedBox(height: 12),
                  Text(product.categoria),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProductBadge(
                        label: '\$${product.precio.toStringAsFixed(2)}',
                        color: AppColors.primary,
                      ),
                      _ProductBadge(
                        label: 'Stock ${product.stock}',
                        color: product.stock <= 5
                            ? AppColors.accent
                            : AppColors.primary,
                      ),
                      _ProductBadge(
                        label: product.activo ? 'Activo' : 'Inactivo',
                        color: product.activo
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrimaryProductCell extends StatelessWidget {
  const _PrimaryProductCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: product.activo ? AppColors.success : AppColors.error,
          foregroundColor: Colors.white,
          child: Text(product.nombre.isNotEmpty
              ? product.nombre[0].toUpperCase()
              : '?'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if ((product.codigo ?? '').isNotEmpty)
                Text(
                  'Codigo: ${product.codigo}',
                  style: TextStyle(color: Colors.blueGrey.shade700),
                ),
              if ((product.descripcion ?? '').isNotEmpty)
                Text(
                  product.descripcion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.blueGrey.shade600),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
