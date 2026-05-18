/// Modelo de sección de menú/catálogo por tenant.
/// Colección Firestore: secciones
class Seccion {
  const Seccion({
    required this.id,
    required this.tenantId,
    required this.nombre,
    required this.posicion,
    required this.activa,
    this.imagenBase64,
    this.imagenFormato,
    this.color,
    this.fechaCreacion,
    this.creadoPor,
    this.modificadoPor,
  });

  final String id;
  final String tenantId;
  final String nombre;

  /// Imagen representativa de la sección (base64).
  final String? imagenBase64;
  final String? imagenFormato;

  /// Color hexadecimal optativo (#RRGGBB).
  final String? color;

  /// Orden de aparición en pantalla.
  final int posicion;
  final bool activa;
  final DateTime? fechaCreacion;
  final String? creadoPor;
  final String? modificadoPor;

  factory Seccion.fromMap(String id, Map<String, dynamic> map) {
    return Seccion(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      imagenBase64: map['imagen_base64']?.toString(),
      imagenFormato: map['imagen_formato']?.toString(),
      color: map['color']?.toString(),
      posicion: (map['posicion'] as num?)?.toInt() ?? 0,
      activa: map['activa'] != false,
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
        'nombre': nombre.trim(),
        'imagen_base64': imagenBase64,
        'imagen_formato': imagenFormato,
        'color': color?.trim(),
        'posicion': posicion,
        'activa': activa,
        'fecha_creacion': fechaCreacion?.toIso8601String(),
        'creado_por': creadoPor?.trim(),
        'modificado_por': modificadoPor?.trim(),
      };

  Seccion copyWith({
    String? id,
    String? tenantId,
    String? nombre,
    String? imagenBase64,
    String? imagenFormato,
    String? color,
    int? posicion,
    bool? activa,
    DateTime? fechaCreacion,
    String? creadoPor,
    String? modificadoPor,
  }) =>
      Seccion(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        nombre: nombre ?? this.nombre,
        imagenBase64: imagenBase64 ?? this.imagenBase64,
        imagenFormato: imagenFormato ?? this.imagenFormato,
        color: color ?? this.color,
        posicion: posicion ?? this.posicion,
        activa: activa ?? this.activa,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        creadoPor: creadoPor ?? this.creadoPor,
        modificadoPor: modificadoPor ?? this.modificadoPor,
      );
}
