class AppUser {
  const AppUser({
    required this.id,
    required this.identificador,
    required this.cedula,
    required this.nombreUsuario,
    required this.nombres,
    required this.apellidos,
    required this.password,
    required this.rol,
    required this.estadoActivo,
    this.tenantId,
    this.fechaCreacion,
    this.email,
    this.telefono,
    this.celular,
    this.direccion,
    this.creadoPor,
    this.modificadoPor,
  });

  final String id;

  /// Código interno manual del usuario, ej. B01, B02, … Bn
  final String identificador;
  final String cedula;
  final String nombreUsuario;
  final String nombres;
  final String apellidos;
  final String password;
  final String rol;
  final bool estadoActivo;

  /// ID del documento en usuario_bios al que pertenece este usuario
  final String? tenantId;

  final DateTime? fechaCreacion;
  final String? email;
  final String? telefono;
  final String? celular;
  final String? direccion;

  /// Auditoría: nombre del usuario que creó/modificó el registro
  final String? creadoPor;
  final String? modificadoPor;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      identificador: (map['identificador'] ?? '').toString(),
      cedula: (map['cedula'] ?? '').toString(),
      nombreUsuario: (map['nombre_usuario'] ?? '').toString(),
      nombres: (map['nombres'] ?? '').toString(),
      apellidos: (map['apellidos'] ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      rol: (map['rol'] ?? 'vendedor').toString(),
      estadoActivo: map['estado_activo'] == true,
      tenantId: map['tenant_id']?.toString(),
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
      'nombre_usuario': nombreUsuario.trim(),
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'password': password.trim(),
      'rol': rol.trim(),
      'estado_activo': estadoActivo,
      'tenant_id': tenantId,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'email': email?.trim(),
      'telefono': telefono?.trim(),
      'celular': celular?.trim(),
      'direccion': direccion?.trim(),
      'creado_por': creadoPor?.trim(),
      'modificado_por': modificadoPor?.trim(),
    };
  }

  AppUser copyWith({
    String? id,
    String? identificador,
    String? cedula,
    String? nombreUsuario,
    String? nombres,
    String? apellidos,
    String? password,
    String? rol,
    bool? estadoActivo,
    String? tenantId,
    DateTime? fechaCreacion,
    String? email,
    String? telefono,
    String? celular,
    String? direccion,
    String? creadoPor,
    String? modificadoPor,
  }) {
    return AppUser(
      id: id ?? this.id,
      identificador: identificador ?? this.identificador,
      cedula: cedula ?? this.cedula,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      password: password ?? this.password,
      rol: rol ?? this.rol,
      estadoActivo: estadoActivo ?? this.estadoActivo,
      tenantId: tenantId ?? this.tenantId,
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
