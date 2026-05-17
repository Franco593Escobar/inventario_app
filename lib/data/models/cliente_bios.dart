// Modelo para los clientes que contratan el servicio BIOS.
// Colección Firestore: cliente_bios
class ClienteBios {
  const ClienteBios({
    required this.id,
    required this.identificador,
    required this.cedula,
    required this.nombreNegocio,
    required this.tipoComercio,
    required this.nombres,
    required this.apellidos,
    required this.nombreUsuario,
    required this.password,
    required this.rol,
    required this.estadoActivo,
    this.activo = false,
    this.fechaCreacion,
    this.email,
    this.telefono,
    this.celular,
    this.direccion,
    this.creadoPor,
    this.modificadoPor,
  });

  final String id;

  /// Código interno, ej. C01, C02, ... Cn
  final String identificador;
  final String cedula;

  /// Nombre comercial del negocio (aparece en dashboard y login)
  final String nombreNegocio;

  /// Tipo de comercio: 'restaurante' | 'comercio' | 'otro'
  final String tipoComercio;

  final String nombres;
  final String apellidos;
  final String nombreUsuario;
  final String password;
  final String rol;
  final bool estadoActivo;

  /// true = es el tenant activo actualmente visible en el dashboard
  final bool activo;

  final DateTime? fechaCreacion;
  final String? email;
  final String? telefono;
  final String? celular;
  final String? direccion;
  final String? creadoPor;
  final String? modificadoPor;

  // ──────────────────────────────────────────────────────────
  // Valores válidos para tipo_comercio
  static const List<String> tiposComercio = [
    'restaurante',
    'comercio',
    'otro',
  ];

  static const Map<String, String> tipoLabel = {
    'restaurante': 'Restaurante',
    'comercio': 'Comercio',
    'otro': 'Otro',
  };
  // ──────────────────────────────────────────────────────────

  factory ClienteBios.fromMap(String id, Map<String, dynamic> map) {
    return ClienteBios(
      id: id,
      identificador: (map['identificador'] ?? '').toString(),
      cedula: (map['cedula'] ?? '').toString(),
      nombreNegocio: (map['nombre_negocio'] ?? '').toString(),
      tipoComercio: (map['tipo_comercio'] ?? 'comercio').toString(),
      nombres: (map['nombres'] ?? '').toString(),
      apellidos: (map['apellidos'] ?? '').toString(),
      nombreUsuario: (map['nombre_usuario'] ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      rol: (map['rol'] ?? 'cliente').toString(),
      estadoActivo: map['estado_activo'] == true,
      activo: map['activo'] == true,
      fechaCreacion: _parseFecha(map['fecha_creacion']),
      email: map['email']?.toString(),
      telefono: map['telefono']?.toString(),
      celular: map['celular']?.toString(),
      direccion: map['direccion']?.toString(),
      creadoPor: map['creado_por']?.toString(),
      modificadoPor: map['modificado_por']?.toString(),
    );
  }

  static DateTime? _parseFecha(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'identificador': identificador.trim(),
      'cedula': cedula.trim(),
      'nombre_negocio': nombreNegocio.trim(),
      'tipo_comercio': tipoComercio.trim(),
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'nombre_usuario': nombreUsuario.trim(),
      'password': password.trim(),
      'rol': rol.trim(),
      'estado_activo': estadoActivo,
      'activo': activo,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'email': email?.trim(),
      'telefono': telefono?.trim(),
      'celular': celular?.trim(),
      'direccion': direccion?.trim(),
      'creado_por': creadoPor?.trim(),
      'modificado_por': modificadoPor?.trim(),
    };
  }

  ClienteBios copyWith({
    String? id,
    String? identificador,
    String? cedula,
    String? nombreNegocio,
    String? tipoComercio,
    String? nombres,
    String? apellidos,
    String? nombreUsuario,
    String? password,
    String? rol,
    bool? estadoActivo,
    bool? activo,
    DateTime? fechaCreacion,
    String? email,
    String? telefono,
    String? celular,
    String? direccion,
    String? creadoPor,
    String? modificadoPor,
  }) {
    return ClienteBios(
      id: id ?? this.id,
      identificador: identificador ?? this.identificador,
      cedula: cedula ?? this.cedula,
      nombreNegocio: nombreNegocio ?? this.nombreNegocio,
      tipoComercio: tipoComercio ?? this.tipoComercio,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      password: password ?? this.password,
      rol: rol ?? this.rol,
      estadoActivo: estadoActivo ?? this.estadoActivo,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      celular: celular ?? this.celular,
      direccion: direccion ?? this.direccion,
      creadoPor: creadoPor ?? this.creadoPor,
      modificadoPor: modificadoPor ?? this.modificadoPor,
    );
  }
}
