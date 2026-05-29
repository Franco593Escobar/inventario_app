/// Modelo de orden/comanda activa por tenant.
/// Colección Firestore: ordenes
class Orden {
  const Orden({
    required this.id,
    required this.tenantId,
    required this.tipo,
    required this.items,
    required this.estado,
    required this.vendedor,
    required this.fechaCreacion,
    this.numeroMesa,
    this.salonId,
    this.salonNombre,
    this.clienteId,
    this.clienteNombre,
    this.clienteTelefono,
    this.clienteDireccion,
    this.costoDelivery = 0.0,
    this.observaciones,
  });

  final String id;
  final String tenantId;

  /// 'mesa' | 'retiro' | 'domicilio' | 'rapida'
  final String tipo;
  final List<OrdenItem> items;

  /// 'abierta' | 'pagada' | 'cancelada'
  final String estado;
  final String vendedor;
  final DateTime fechaCreacion;
  final int? numeroMesa;
  final String? salonId;
  final String? salonNombre;
  final String? clienteId;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? clienteDireccion;
  final double costoDelivery;
  final String? observaciones;

  double get subtotal => items.fold(0.0, (a, i) => a + i.subtotal);
  double get total => subtotal + costoDelivery;

  String get etiqueta => switch (tipo) {
        'mesa' => 'Mesa ${numeroMesa ?? "?"}',
        'retiro' =>
          (clienteNombre?.isNotEmpty ?? false) ? clienteNombre! : 'Retiro',
        'domicilio' =>
          (clienteNombre?.isNotEmpty ?? false) ? clienteNombre! : 'Domicilio',
        _ => 'Venta Rápida',
      };

  factory Orden.fromMap(String id, Map<String, dynamic> map) {
    return Orden(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      tipo: (map['tipo'] ?? 'rapida').toString(),
      items: (map['items'] as List? ?? [])
          .map((e) => OrdenItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      estado: (map['estado'] ?? 'abierta').toString(),
      vendedor: (map['vendedor'] ?? '').toString(),
      fechaCreacion: _parseFecha(map['fecha_creacion']) ?? DateTime.now(),
      numeroMesa: (map['numero_mesa'] as num?)?.toInt(),
      salonId: map['salon_id']?.toString(),
      salonNombre: map['salon_nombre']?.toString(),
      clienteId: map['cliente_id']?.toString(),
      clienteNombre: map['cliente_nombre']?.toString(),
      clienteTelefono: map['cliente_telefono']?.toString(),
      clienteDireccion: map['cliente_direccion']?.toString(),
      costoDelivery: (map['costo_delivery'] as num?)?.toDouble() ?? 0.0,
      observaciones: map['observaciones']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tenant_id': tenantId,
        'tipo': tipo,
        'items': items.map((i) => i.toMap()).toList(),
        'estado': estado,
        'vendedor': vendedor,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'numero_mesa': numeroMesa,
        'salon_id': salonId,
        'salon_nombre': salonNombre,
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'cliente_telefono': clienteTelefono,
        'cliente_direccion': clienteDireccion,
        'costo_delivery': costoDelivery,
        'observaciones': observaciones,
      };

  Orden copyWith({
    String? id,
    List<OrdenItem>? items,
    String? estado,
    double? costoDelivery,
    String? observaciones,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteDireccion,
  }) =>
      Orden(
        id: id ?? this.id,
        tenantId: tenantId,
        tipo: tipo,
        items: items ?? this.items,
        estado: estado ?? this.estado,
        vendedor: vendedor,
        fechaCreacion: fechaCreacion,
        numeroMesa: numeroMesa,
        salonId: salonId,
        salonNombre: salonNombre,
        clienteId: clienteId ?? this.clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        clienteTelefono: clienteTelefono ?? this.clienteTelefono,
        clienteDireccion: clienteDireccion ?? this.clienteDireccion,
        costoDelivery: costoDelivery ?? this.costoDelivery,
        observaciones: observaciones ?? this.observaciones,
      );

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

class OrdenItem {
  const OrdenItem({
    required this.productoId,
    required this.nombre,
    required this.codigo,
    required this.precio,
    required this.cantidad,
    required this.subtotal,
    this.impuesto = '',
    this.nota,
  });

  final String productoId;
  final String nombre;
  final String codigo;
  final double precio;
  final double cantidad;
  final double subtotal;
  final String impuesto;
  final String? nota;

  factory OrdenItem.fromMap(Map<String, dynamic> map) {
    return OrdenItem(
      productoId: (map['producto_id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      precio: (map['precio'] as num?)?.toDouble() ?? 0,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      impuesto: (map['impuesto'] ?? '').toString(),
      nota: map['nota']?.toString(),
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
        'nota': nota,
      };

  OrdenItem conCantidad(double nuevaCantidad) => OrdenItem(
        productoId: productoId,
        nombre: nombre,
        codigo: codigo,
        precio: precio,
        cantidad: nuevaCantidad,
        subtotal: precio * nuevaCantidad,
        impuesto: impuesto,
        nota: nota,
      );
}
