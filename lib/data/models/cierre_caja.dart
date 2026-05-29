/// Modelo de cierre de caja.
/// Colección Firestore: cierres_caja
class CierreCaja {
  const CierreCaja({
    required this.id,
    required this.tenantId,
    required this.operador,
    required this.fechaApertura,
    required this.fechaCierre,
    required this.fondoInicial,
    required this.totalEfectivo,
    required this.totalTarjeta,
    required this.totalTransferencia,
    required this.totalOtros,
    required this.efectivoContado,
    required this.denominaciones,
    required this.diferencia,
    required this.cantidadVentas,
    this.observaciones,
  });

  final String id;
  final String tenantId;
  final String operador;
  final DateTime fechaApertura;
  final DateTime fechaCierre;

  /// Fondo inicial en caja al abrir el turno.
  final double fondoInicial;

  /// Total cobrado en efectivo (de las ventas).
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalTransferencia;
  final double totalOtros;

  double get totalVentas =>
      totalEfectivo + totalTarjeta + totalTransferencia + totalOtros;

  /// Suma del conteo físico de billetes y monedas.
  final double efectivoContado;

  /// Mapa de denominación → cantidad contada. Ej: {'100': 2, '50': 3}
  final Map<String, int> denominaciones;

  /// efectivoContado - (fondoInicial + totalEfectivo)
  final double diferencia;
  final int cantidadVentas;
  final String? observaciones;

  factory CierreCaja.fromMap(String id, Map<String, dynamic> map) {
    final denom = <String, int>{};
    final rawDenom = map['denominaciones'];
    if (rawDenom is Map) {
      rawDenom.forEach((k, v) {
        denom[k.toString()] = (v as num).toInt();
      });
    }
    return CierreCaja(
      id: id,
      tenantId: (map['tenant_id'] ?? '').toString(),
      operador: (map['operador'] ?? '').toString(),
      fechaApertura: _parseFecha(map['fecha_apertura']) ?? DateTime.now(),
      fechaCierre: _parseFecha(map['fecha_cierre']) ?? DateTime.now(),
      fondoInicial: (map['fondo_inicial'] as num?)?.toDouble() ?? 0,
      totalEfectivo: (map['total_efectivo'] as num?)?.toDouble() ?? 0,
      totalTarjeta: (map['total_tarjeta'] as num?)?.toDouble() ?? 0,
      totalTransferencia: (map['total_transferencia'] as num?)?.toDouble() ?? 0,
      totalOtros: (map['total_otros'] as num?)?.toDouble() ?? 0,
      efectivoContado: (map['efectivo_contado'] as num?)?.toDouble() ?? 0,
      denominaciones: denom,
      diferencia: (map['diferencia'] as num?)?.toDouble() ?? 0,
      cantidadVentas: (map['cantidad_ventas'] as num?)?.toInt() ?? 0,
      observaciones: map['observaciones']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tenant_id': tenantId,
        'operador': operador,
        'fecha_apertura': fechaApertura.toIso8601String(),
        'fecha_cierre': fechaCierre.toIso8601String(),
        'fondo_inicial': fondoInicial,
        'total_efectivo': totalEfectivo,
        'total_tarjeta': totalTarjeta,
        'total_transferencia': totalTransferencia,
        'total_otros': totalOtros,
        'efectivo_contado': efectivoContado,
        'denominaciones': denominaciones,
        'diferencia': diferencia,
        'cantidad_ventas': cantidadVentas,
        'observaciones': observaciones,
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
