/// Modelo de proveedor por tenant.
/// Colección Firestore: proveedores
class Proveedor {
  const Proveedor({
    required this.id,
    required this.tenantId,
    required this.identificador,
    required this.nombre,
    required this.activo,
    this.ruc = '',
    this.telefono,
    this.email,
    this.direccion,
    this.contacto,
    this.fechaCreacion,
    this.creadoPor,
    this.modificadoPor,
  });

  final String id;
  final String tenantId;

  /// Código interno: P001, P002…
  final String identificador;
  final String nombre;
  final String ruc;
  final bool activo;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? contacto;
  final DateTime? fechaCreacion;
  final String? creadoPor;
  final String? modificadoPor;

  factory Proveedor.fromMap(String id, Map<String, dynamic> map) {
    return Proveedor(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      identificador: (map['identificador'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      ruc: (map['ruc'] ?? '').toString(),
      activo: map['activo'] != false,
      telefono: map['telefono']?.toString(),
      email: map['email']?.toString(),
      direccion: map['direccion']?.toString(),
      contacto: map['contacto']?.toString(),
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
        'identificador': identificador.trim(),
        'nombre': nombre.trim(),
        'ruc': ruc.trim(),
        'activo': activo,
        'telefono': telefono?.trim(),
        'email': email?.trim(),
        'direccion': direccion?.trim(),
        'contacto': contacto?.trim(),
        'fecha_creacion': fechaCreacion?.toIso8601String(),
        'creado_por': creadoPor?.trim(),
        'modificado_por': modificadoPor?.trim(),
      };

  Proveedor copyWith({
    String? id,
    String? tenantId,
    String? identificador,
    String? nombre,
    String? ruc,
    bool? activo,
    String? telefono,
    String? email,
    String? direccion,
    String? contacto,
    DateTime? fechaCreacion,
    String? creadoPor,
    String? modificadoPor,
  }) =>
      Proveedor(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        identificador: identificador ?? this.identificador,
        nombre: nombre ?? this.nombre,
        ruc: ruc ?? this.ruc,
        activo: activo ?? this.activo,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        direccion: direccion ?? this.direccion,
        contacto: contacto ?? this.contacto,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        creadoPor: creadoPor ?? this.creadoPor,
        modificadoPor: modificadoPor ?? this.modificadoPor,
      );
}
