class Product {
  const Product({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.precio,
    required this.stock,
    required this.activo,
    this.codigo,
    this.descripcion,
  });

  final String id;
  final String nombre;
  final String categoria;
  final double precio;
  final int stock;
  final bool activo;
  final String? codigo;
  final String? descripcion;

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      nombre: (map['nombre'] ?? '').toString(),
      categoria: (map['categoria'] ?? 'general').toString(),
      precio: (map['precio'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      activo: map['activo'] != false,
      codigo: map['codigo']?.toString(),
      descripcion: map['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre.trim(),
      'categoria': categoria.trim(),
      'precio': precio,
      'stock': stock,
      'activo': activo,
      'codigo': codigo?.trim(),
      'descripcion': descripcion?.trim(),
    };
  }

  Product copyWith({
    String? id,
    String? nombre,
    String? categoria,
    double? precio,
    int? stock,
    bool? activo,
    String? codigo,
    String? descripcion,
  }) {
    return Product(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      activo: activo ?? this.activo,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}
