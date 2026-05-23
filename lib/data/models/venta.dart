/// Modelo de venta por tenant.
/// Colección Firestore: ventas
class Venta {
  const Venta({
    required this.id,
    required this.tenantId,
    required this.items,
    required this.subtotal,
    required this.totalImpuesto,
    required this.total,
    required this.metodoPago,
    required this.vendedor,
    required this.estado,
    required this.fecha,
    this.observaciones,
    this.creadoPor,
  });

  final String id;
  final String tenantId;
  final List<VentaItem> items;
  final double subtotal;
  final double totalImpuesto;
  final double total;

  /// 'efectivo' | 'tarjeta' | 'transferencia'
  final String metodoPago;
  final String vendedor;

  /// 'completada' | 'anulada'
  final String estado;
  final DateTime fecha;
  final String? observaciones;
  final String? creadoPor;

  factory Venta.fromMap(String id, Map<String, dynamic> map) {
    return Venta(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      items: (map['items'] as List? ?? [])
          .map((e) => VentaItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      totalImpuesto: (map['total_impuesto'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      metodoPago: (map['metodo_pago'] ?? 'efectivo').toString(),
      vendedor: (map['vendedor'] ?? '').toString(),
      estado: (map['estado'] ?? 'completada').toString(),
      fecha: _parseFecha(map['fecha']) ?? DateTime.now(),
      observaciones: map['observaciones']?.toString(),
      creadoPor: map['creado_por']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tenant_id': tenantId,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'total_impuesto': totalImpuesto,
        'total': total,
        'metodo_pago': metodoPago,
        'vendedor': vendedor,
        'estado': estado,
        'fecha': fecha.toIso8601String(),
        'observaciones': observaciones,
        'creado_por': creadoPor,
      };

  static DateTime? _parseFecha(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}

class VentaItem {
  const VentaItem({
    required this.productoId,
    required this.nombre,
    required this.codigo,
    required this.precio,
    required this.cantidad,
    required this.subtotal,
    this.impuesto = '',
  });

  final String productoId;
  final String nombre;
  final String codigo;
  final double precio;
  final double cantidad;
  final double subtotal;
  final String impuesto;

  factory VentaItem.fromMap(Map<String, dynamic> map) {
    return VentaItem(
      productoId: (map['producto_id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      precio: (map['precio'] as num?)?.toDouble() ?? 0,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      impuesto: (map['impuesto'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'producto_id': productoId,
        'nombre': nombre,
        'codigo': codigo,
        'precio': precio,
        'cantidad': cantidad,
        'subtotal': subtotal,
        'impuesto': impuesto,
      };

  VentaItem conCantidad(double nuevaCantidad) => VentaItem(
        productoId: productoId,
        nombre: nombre,
        codigo: codigo,
        precio: precio,
        cantidad: nuevaCantidad,
        subtotal: precio * nuevaCantidad,
        impuesto: impuesto,
      );
}
