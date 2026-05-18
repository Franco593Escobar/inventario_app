/// Modelo para los negocios que contratan el servicio BIOS.
/// Colección Firestore: usuario_bios
class UsuarioBios {
  const UsuarioBios({
    required this.id,
    required this.identificador,
    required this.cedula,
    required this.nombreNegocio,
    required this.tipoComercio,
    required this.dueno,
    required this.pagoServicio,
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

  /// Código interno, ej. N01, N02, … Nn
  final String identificador;
  final String cedula;

  /// Nombre comercial del negocio (aparece en dashboard y login)
  final String nombreNegocio;

  /// Tipo de comercio: 'restaurante' | 'comercio' | 'otro'
  final String tipoComercio;

  /// Nombre completo del dueño del negocio, ej. "Fabian Ramon"
  final String dueno;

  /// Plan de pago: 'indefinido' | 'anual' | 'mensual' | 'demo'
  final String pagoServicio;

  final String nombres;
  final String apellidos;

  /// Nombre de usuario admin para login en el sistema
  final String nombreUsuario;

  /// Contraseña del usuario admin
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

  static const List<String> tiposComercio = [
    'restaurante',
    'comercio',
    'kiosko',
    'otro',
  ];

  static const Map<String, String> tipoLabel = {
    'restaurante': 'Restaurante',
    'comercio': 'Comercio',
    'kiosko': 'Kiosko',
    'otro': 'Otro',
  };

  static const List<String> pagoServicios = [
    'indefinido',
    'anual',
    'mensual',
    'demo',
  ];

  static const Map<String, String> pagoLabel = {
    'indefinido': 'Indefinido',
    'anual': 'Anual',
    'mensual': 'Mensual',
    'demo': 'Demo',
  };

  // ──────────────────────────────────────────────────────────

  factory UsuarioBios.fromMap(String id, Map<String, dynamic> map) {
    return UsuarioBios(
      id: id,
      identificador: (map['identificador'] ?? '').toString(),
      cedula: (map['cedula'] ?? '').toString(),
      nombreNegocio: (map['nombre_negocio'] ?? '').toString(),
      tipoComercio: (map['tipo_comercio'] ?? 'comercio').toString(),
      dueno: (map['dueno'] ?? map['dueño'] ?? '').toString(),
      pagoServicio: (map['pago_servicio'] ?? 'indefinido').toString(),
      nombres: (map['nombres'] ?? '').toString(),
      apellidos: (map['apellidos'] ?? '').toString(),
      nombreUsuario: (map['nombre_usuario'] ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      rol: (map['rol'] ?? 'admin').toString(),
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
      'dueno': dueno.trim(),
      'pago_servicio': pagoServicio.trim(),
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'nombre_usuario': nombreUsuario.trim(),
      'password': password.trim(),
      'rol': rol.trim(),
      'estado_activo': estadoActivo,
      'activo': activo,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      if (email != null) 'email': email!.trim(),
      if (telefono != null) 'telefono': telefono!.trim(),
      if (celular != null) 'celular': celular!.trim(),
      if (direccion != null) 'direccion': direccion!.trim(),
      if (creadoPor != null) 'creado_por': creadoPor!.trim(),
      if (modificadoPor != null) 'modificado_por': modificadoPor!.trim(),
    };
  }

  UsuarioBios copyWith({
    String? id,
    String? identificador,
    String? cedula,
    String? nombreNegocio,
    String? tipoComercio,
    String? dueno,
    String? pagoServicio,
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
    return UsuarioBios(
      id: id ?? this.id,
      identificador: identificador ?? this.identificador,
      cedula: cedula ?? this.cedula,
      nombreNegocio: nombreNegocio ?? this.nombreNegocio,
      tipoComercio: tipoComercio ?? this.tipoComercio,
      dueno: dueno ?? this.dueno,
      pagoServicio: pagoServicio ?? this.pagoServicio,
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
