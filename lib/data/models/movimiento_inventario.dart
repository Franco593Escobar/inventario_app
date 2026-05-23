/// Modelo de movimiento de inventario.
/// Colección Firestore: movimientos_inventario
class MovimientoInventario {
  const MovimientoInventario({
    required this.id,
    required this.tenantId,
    required this.productoId,
    required this.productoNombre,
    required this.tipo,
    required this.cantidad,
    required this.stockAnterior,
    required this.stockNuevo,
    required this.motivo,
    required this.operador,
    required this.fecha,
  });

  final String id;
  final String tenantId;
  final String productoId;
  final String productoNombre;

  /// 'entrada' | 'salida' | 'ajuste'
  final String tipo;
  final int cantidad;
  final int stockAnterior;
  final int stockNuevo;
  final String motivo;
  final String operador;
  final DateTime fecha;

  factory MovimientoInventario.fromMap(String id, Map<String, dynamic> map) {
    return MovimientoInventario(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      productoId: (map['producto_id'] ?? '').toString(),
      productoNombre: (map['producto_nombre'] ?? '').toString(),
      tipo: (map['tipo'] ?? 'entrada').toString(),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      stockAnterior: (map['stock_anterior'] as num?)?.toInt() ?? 0,
      stockNuevo: (map['stock_nuevo'] as num?)?.toInt() ?? 0,
      motivo: (map['motivo'] ?? '').toString(),
      operador: (map['operador'] ?? '').toString(),
      fecha: _parseFecha(map['fecha']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tenant_id': tenantId,
        'producto_id': productoId,
        'producto_nombre': productoNombre,
        'tipo': tipo,
        'cantidad': cantidad,
        'stock_anterior': stockAnterior,
        'stock_nuevo': stockNuevo,
        'motivo': motivo,
        'operador': operador,
        'fecha': fecha.toIso8601String(),
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
