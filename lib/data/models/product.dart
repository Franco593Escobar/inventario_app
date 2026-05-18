/// Modelo de producto por tenant.
/// Colección Firestore: productos
class Product {
  const Product({
    required this.id,
    required this.tenantId,
    required this.codigo,
    required this.nombre,
    required this.impuesto,
    required this.costo,
    required this.stock,
    required this.stockMinimo,
    required this.precioVenta,
    required this.ubicacion,
    required this.vendidoEn,
    required this.mostrarEnVentas,
    required this.posicionPantalla,
    required this.mostrarEnPedidos,
    required this.codigosAdicionales,
    required this.activo,
    this.proveedorId,
    this.proveedorNombre,
    this.seccionId,
    this.seccionNombre,
    this.imagenBase64,
    this.imagenFormato,
    this.descripcion,
    this.fechaCreacion,
    this.creadoPor,
    this.modificadoPor,
  });

  final String id;
  final String tenantId;

  /// Código de barras principal.
  final String codigo;
  final String nombre;
  final String? proveedorId;
  final String? proveedorNombre;

  /// 'IVA 0%' | 'IVA 15%' | 'Exento' | 'No objeto'.
  final String impuesto;
  final double costo;
  final int stock;
  final int stockMinimo;

  /// Precio de venta incluye impuesto.
  final double precioVenta;

  /// Ubicaciones de preparación, ej: ['COCINA', 'BARRA'].
  final List<String> ubicacion;

  final String? seccionId;
  final String? seccionNombre;

  /// 'unidades' | 'decimales'
  final String vendidoEn;
  final bool mostrarEnVentas;
  final int posicionPantalla;
  final bool mostrarEnPedidos;
  final String? imagenBase64;
  final String? imagenFormato;
  final String? descripcion;
  final List<String> codigosAdicionales;
  final bool activo;
  final DateTime? fechaCreacion;
  final String? creadoPor;
  final String? modificadoPor;

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    List<String> parseList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return Product(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      proveedorId: map['proveedor_id']?.toString(),
      proveedorNombre: map['proveedor_nombre']?.toString(),
      impuesto: (map['impuesto'] ?? 'IVA 15%').toString(),
      costo: (map['costo'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      stockMinimo: (map['stock_minimo'] as num?)?.toInt() ?? 0,
      precioVenta: (map['precio_venta'] as num?)?.toDouble() ?? 0,
      ubicacion: parseList(map['ubicacion']),
      seccionId: map['seccion_id']?.toString(),
      seccionNombre: map['seccion_nombre']?.toString(),
      vendidoEn: (map['vendido_en'] ?? 'unidades').toString(),
      mostrarEnVentas: map['mostrar_en_ventas'] != false,
      posicionPantalla: (map['posicion_pantalla'] as num?)?.toInt() ?? 0,
      mostrarEnPedidos: map['mostrar_en_pedidos'] ?? false,
      imagenBase64: map['imagen_base64']?.toString(),
      imagenFormato: map['imagen_formato']?.toString(),
      descripcion: map['descripcion']?.toString(),
      codigosAdicionales: parseList(map['codigos_adicionales']),
      activo: map['activo'] != false,
      fechaCreacion: _parseFecha(map['fecha_creacion']),
      creadoPor: map['creado_por']?.toString(),
      modificadoPor: map['modificado_por']?.toString(),
    );
  }

  static DateTime? _parseFecha(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
        'tenant_id': tenantId,
        'codigo': codigo.trim(),
        'nombre': nombre.trim(),
        'proveedor_id': proveedorId,
        'proveedor_nombre': proveedorNombre,
        'impuesto': impuesto,
        'costo': costo,
        'stock': stock,
        'stock_minimo': stockMinimo,
        'precio_venta': precioVenta,
        'ubicacion': ubicacion,
        'seccion_id': seccionId,
        'seccion_nombre': seccionNombre,
        'vendido_en': vendidoEn,
        'mostrar_en_ventas': mostrarEnVentas,
        'posicion_pantalla': posicionPantalla,
        'mostrar_en_pedidos': mostrarEnPedidos,
        'imagen_base64': imagenBase64,
        'imagen_formato': imagenFormato,
        'descripcion': descripcion?.trim(),
        'codigos_adicionales': codigosAdicionales,
        'activo': activo,
        'fecha_creacion': fechaCreacion?.toIso8601String(),
        'creado_por': creadoPor?.trim(),
        'modificado_por': modificadoPor?.trim(),
      };

  Product copyWith({
    String? id,
    String? tenantId,
    String? codigo,
    String? nombre,
    String? proveedorId,
    String? proveedorNombre,
    String? impuesto,
    double? costo,
    int? stock,
    int? stockMinimo,
    double? precioVenta,
    List<String>? ubicacion,
    String? seccionId,
    String? seccionNombre,
    String? vendidoEn,
    bool? mostrarEnVentas,
    int? posicionPantalla,
    bool? mostrarEnPedidos,
    String? imagenBase64,
    String? imagenFormato,
    String? descripcion,
    List<String>? codigosAdicionales,
    bool? activo,
    DateTime? fechaCreacion,
    String? creadoPor,
    String? modificadoPor,
  }) =>
      Product(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        codigo: codigo ?? this.codigo,
        nombre: nombre ?? this.nombre,
        proveedorId: proveedorId ?? this.proveedorId,
        proveedorNombre: proveedorNombre ?? this.proveedorNombre,
        impuesto: impuesto ?? this.impuesto,
        costo: costo ?? this.costo,
        stock: stock ?? this.stock,
        stockMinimo: stockMinimo ?? this.stockMinimo,
        precioVenta: precioVenta ?? this.precioVenta,
        ubicacion: ubicacion ?? this.ubicacion,
        seccionId: seccionId ?? this.seccionId,
        seccionNombre: seccionNombre ?? this.seccionNombre,
        vendidoEn: vendidoEn ?? this.vendidoEn,
        mostrarEnVentas: mostrarEnVentas ?? this.mostrarEnVentas,
        posicionPantalla: posicionPantalla ?? this.posicionPantalla,
        mostrarEnPedidos: mostrarEnPedidos ?? this.mostrarEnPedidos,
        imagenBase64: imagenBase64 ?? this.imagenBase64,
        imagenFormato: imagenFormato ?? this.imagenFormato,
        descripcion: descripcion ?? this.descripcion,
        codigosAdicionales: codigosAdicionales ?? this.codigosAdicionales,
        activo: activo ?? this.activo,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        creadoPor: creadoPor ?? this.creadoPor,
        modificadoPor: modificadoPor ?? this.modificadoPor,
      );
}
