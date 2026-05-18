/// Modelo de identidad de marca para un negocio BIOS.
/// Colección Firestore: marca_bios
class MarcaBios {
  const MarcaBios({
    required this.id,
    required this.negocioId,
    required this.nombreNegocio,
    required this.colorPrimario,
    this.cromatica = const [],
    this.logoBase64,
    this.logoFormato,
    this.fechaCreacion,
    this.creadoPor,
    this.modificadoPor,
  });

  /// ID del documento Firestore
  final String id;

  /// ID del documento `usuario_bios` al que pertenece esta marca
  final String negocioId;

  /// Nombre comercial del negocio (desnormalizado para mostrar)
  final String nombreNegocio;

  /// Color primario en formato HEX, ej. '#1E2E51'
  final String colorPrimario;

  /// Paleta cromática secundaria: lista de HEX, ej. ['#FF5733', '#FFC300']
  final List<String> cromatica;

  /// Logo codificado en base64 (PNG / JPG / JPEG / BMP)
  final String? logoBase64;

  /// Formato del logo: 'png' | 'jpg' | 'jpeg' | 'bmp'
  final String? logoFormato;

  final DateTime? fechaCreacion;
  final String? creadoPor;
  final String? modificadoPor;

  // ──────────────────────────────────────────────────────────

  static MarcaBios fromMap(String id, Map<String, dynamic> m) {
    List<String> parseCromatica() {
      final raw = m['cromatica'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return MarcaBios(
      id: id,
      negocioId: m['negocioId'] as String? ?? '',
      nombreNegocio: m['nombreNegocio'] as String? ?? '',
      colorPrimario: m['colorPrimario'] as String? ?? '#1E2E51',
      cromatica: parseCromatica(),
      logoBase64: m['logoBase64'] as String?,
      logoFormato: m['logoFormato'] as String?,
      fechaCreacion: (m['fechaCreacion'] as dynamic)?.toDate() as DateTime?,
      creadoPor: m['creadoPor'] as String?,
      modificadoPor: m['modificadoPor'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'negocioId': negocioId,
        'nombreNegocio': nombreNegocio,
        'colorPrimario': colorPrimario,
        'cromatica': cromatica,
        'logoBase64': logoBase64,
        'logoFormato': logoFormato,
        'fechaCreacion': fechaCreacion,
        'creadoPor': creadoPor,
        'modificadoPor': modificadoPor,
      };

  MarcaBios copyWith({
    String? negocioId,
    String? nombreNegocio,
    String? colorPrimario,
    List<String>? cromatica,
    String? logoBase64,
    String? logoFormato,
    DateTime? fechaCreacion,
    String? creadoPor,
    String? modificadoPor,
  }) =>
      MarcaBios(
        id: id,
        negocioId: negocioId ?? this.negocioId,
        nombreNegocio: nombreNegocio ?? this.nombreNegocio,
        colorPrimario: colorPrimario ?? this.colorPrimario,
        cromatica: cromatica ?? this.cromatica,
        logoBase64: logoBase64 ?? this.logoBase64,
        logoFormato: logoFormato ?? this.logoFormato,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        creadoPor: creadoPor ?? this.creadoPor,
        modificadoPor: modificadoPor ?? this.modificadoPor,
      );
}
