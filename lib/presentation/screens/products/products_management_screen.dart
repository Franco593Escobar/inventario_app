import 'package:flutter/material.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/product.dart';
import 'package:inventario_app/data/repositories/product_repository.dart';

class ProductsManagementScreen extends StatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  State<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState extends State<ProductsManagementScreen> {
  final ProductRepository _repository = ProductRepository();

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

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(product == null ? 'Nuevo producto' : 'Editar producto'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreController,
                          decoration:
                              const InputDecoration(labelText: 'Nombre'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ingresa el nombre'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codigoController,
                          decoration:
                              const InputDecoration(labelText: 'Código'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: categoriaController,
                          decoration:
                              const InputDecoration(labelText: 'Categoría'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ingresa la categoría'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descripcionController,
                          decoration:
                              const InputDecoration(labelText: 'Descripción'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: precioController,
                          decoration:
                              const InputDecoration(labelText: 'Precio'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            return parsed == null
                                ? 'Ingresa un precio válido'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: stockController,
                          decoration: const InputDecoration(labelText: 'Stock'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            return parsed == null
                                ? 'Ingresa un stock válido'
                                : null;
                          },
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
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

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

                    if (product == null) {
                      await _repository.createProduct(draft);
                    } else {
                      await _repository.updateProduct(draft);
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Guardar'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(product == null
              ? 'Producto creado correctamente'
              : 'Producto actualizado correctamente'),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que deseas eliminar ${product.nombre}? Esta acción no se puede deshacer.',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto eliminado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Gestión de productos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openProductForm,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Nuevo producto'),
      ),
      body: StreamBuilder<List<Product>>(
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
          if (products.isEmpty) {
            return const Center(
              child: Text('No hay productos registrados todavía.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor:
                        product.activo ? AppColors.success : AppColors.error,
                    foregroundColor: Colors.white,
                    child: Text(
                      product.nombre.isNotEmpty
                          ? product.nombre[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(product.nombre),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Categoría: ${product.categoria}'),
                      const SizedBox(height: 4),
                      Text(
                          'Precio: ${product.precio.toStringAsFixed(2)} | Stock: ${product.stock}'),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => _openProductForm(product),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () => _deleteProduct(product),
                        icon: const Icon(Icons.delete_outline),
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
  }
}
