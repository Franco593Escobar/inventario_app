import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de documento para identificar al cliente
enum TipoDocumento { ci, ruc, pasaporte }

class Cliente {
  final String id;
  final String tenantId;
  final TipoDocumento tipoDocumento;
  final String numeroDocumento;
  final String nombres;
  final String apellidos;
  final String telefono;
  final String celular;
  final String email;
  final String direccion;
  final String provincia;
  final bool activo;
  final DateTime? fechaCreacion;

  const Cliente({
    required this.id,
    required this.tenantId,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.nombres,
    required this.apellidos,
    this.telefono = '',
    this.celular = '',
    this.email = '',
    this.direccion = '',
    this.provincia = '',
    this.activo = true,
    this.fechaCreacion,
  });

  /// Nombre completo para mostrar en UI
  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// Documento con tipo: "CI: 1234567890"
  String get documentoLabel =>
      '${tipoDocumento.name.toUpperCase()}: $numeroDocumento';

  /// true si es consumidor final (doc reservado)
  bool get esConsumidorFinal => numeroDocumento == '9999999999';

  /// Cliente Consumidor Final por defecto
  static Cliente consumidorFinal(String tenantId) => Cliente(
        id: '__consumidor_final__',
        tenantId: tenantId,
        tipoDocumento: TipoDocumento.ci,
        numeroDocumento: '9999999999',
        nombres: 'Consumidor',
        apellidos: 'Final',
      );

  factory Cliente.fromMap(String id, Map<String, dynamic> map) => Cliente(
        id: id,
        tenantId: map['tenantId'] as String,
        tipoDocumento: _parseTipoDoc(map['tipoDocumento'] as String?),
        numeroDocumento: map['numeroDocumento'] as String,
        nombres: map['nombres'] as String,
        apellidos: map['apellidos'] as String,
        telefono: (map['telefono'] as String?) ?? '',
        celular: (map['celular'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        direccion: (map['direccion'] as String?) ?? '',
        provincia: (map['provincia'] as String?) ?? '',
        activo: (map['activo'] as bool?) ?? true,
        fechaCreacion: map['fechaCreacion'] != null
            ? (map['fechaCreacion'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'tenantId': tenantId,
        'tipoDocumento': tipoDocumento.name,
        'numeroDocumento': numeroDocumento,
        'nombres': nombres,
        'apellidos': apellidos,
        'telefono': telefono,
        'celular': celular,
        'email': email,
        'direccion': direccion,
        'provincia': provincia,
        'activo': activo,
        'fechaCreacion': fechaCreacion != null
            ? Timestamp.fromDate(fechaCreacion!)
            : FieldValue.serverTimestamp(),
      };

  Cliente copyWith({
    String? id,
    String? tenantId,
    TipoDocumento? tipoDocumento,
    String? numeroDocumento,
    String? nombres,
    String? apellidos,
    String? telefono,
    String? celular,
    String? email,
    String? direccion,
    String? provincia,
    bool? activo,
    DateTime? fechaCreacion,
  }) =>
      Cliente(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        tipoDocumento: tipoDocumento ?? this.tipoDocumento,
        numeroDocumento: numeroDocumento ?? this.numeroDocumento,
        nombres: nombres ?? this.nombres,
        apellidos: apellidos ?? this.apellidos,
        telefono: telefono ?? this.telefono,
        celular: celular ?? this.celular,
        email: email ?? this.email,
        direccion: direccion ?? this.direccion,
        provincia: provincia ?? this.provincia,
        activo: activo ?? this.activo,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      );

  static TipoDocumento _parseTipoDoc(String? value) => switch (value) {
        'ruc' => TipoDocumento.ruc,
        'pasaporte' => TipoDocumento.pasaporte,
        _ => TipoDocumento.ci,
      };
}
