class AppUser {
  const AppUser({
    required this.id,
    required this.nombreUsuario,
    required this.nombres,
    required this.password,
    required this.rol,
    required this.estadoActivo,
    this.email,
    this.apellidos,
    this.telefono,
  });

  final String id;
  final String nombreUsuario;
  final String nombres;
  final String password;
  final String rol;
  final bool estadoActivo;
  final String? email;
  final String? apellidos;
  final String? telefono;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      nombreUsuario: (map['nombre_usuario'] ?? '').toString(),
      nombres: (map['nombres'] ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      rol: (map['rol'] ?? 'vendedor').toString(),
      estadoActivo: map['estado_activo'] == true,
      email: map['email']?.toString(),
      apellidos: map['apellidos']?.toString(),
      telefono: map['telefono']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre_usuario': nombreUsuario.trim(),
      'nombres': nombres.trim(),
      'password': password.trim(),
      'rol': rol.trim(),
      'estado_activo': estadoActivo,
      'email': email?.trim(),
      'apellidos': apellidos?.trim(),
      'telefono': telefono?.trim(),
    };
  }

  AppUser copyWith({
    String? id,
    String? nombreUsuario,
    String? nombres,
    String? password,
    String? rol,
    bool? estadoActivo,
    String? email,
    String? apellidos,
    String? telefono,
  }) {
    return AppUser(
      id: id ?? this.id,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      nombres: nombres ?? this.nombres,
      password: password ?? this.password,
      rol: rol ?? this.rol,
      estadoActivo: estadoActivo ?? this.estadoActivo,
      email: email ?? this.email,
      apellidos: apellidos ?? this.apellidos,
      telefono: telefono ?? this.telefono,
    );
  }
}
