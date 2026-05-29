import 'package:cloud_firestore/cloud_firestore.dart';

class Mesa {
  final int numero;
  final String nombre;
  final int capacidad;
  final bool activa;

  const Mesa({
    required this.numero,
    required this.nombre,
    required this.capacidad,
    this.activa = true,
  });

  factory Mesa.fromMap(Map<String, dynamic> map) => Mesa(
        numero: (map['numero'] as num).toInt(),
        nombre: (map['nombre'] as String?) ?? 'Mesa ${map['numero']}',
        capacidad: (map['capacidad'] as num?)?.toInt() ?? 4,
        activa: (map['activa'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'nombre': nombre,
        'capacidad': capacidad,
        'activa': activa,
      };

  Mesa copyWith({
    int? numero,
    String? nombre,
    int? capacidad,
    bool? activa,
  }) =>
      Mesa(
        numero: numero ?? this.numero,
        nombre: nombre ?? this.nombre,
        capacidad: capacidad ?? this.capacidad,
        activa: activa ?? this.activa,
      );
}

class Salon {
  final String id;
  final String tenantId;
  final String nombre;
  final String descripcion;
  final bool activo;
  final List<Mesa> mesas;
  final DateTime? fechaCreacion;

  const Salon({
    required this.id,
    required this.tenantId,
    required this.nombre,
    this.descripcion = '',
    this.activo = true,
    this.mesas = const [],
    this.fechaCreacion,
  });

  int get totalMesas => mesas.length;
  int get mesasActivas => mesas.where((m) => m.activa).length;

  factory Salon.fromMap(String id, Map<String, dynamic> map) => Salon(
        id: id,
        tenantId: map['tenantId'] as String,
        nombre: map['nombre'] as String,
        descripcion: (map['descripcion'] as String?) ?? '',
        activo: (map['activo'] as bool?) ?? true,
        mesas: ((map['mesas'] as List<dynamic>?) ?? [])
            .map((m) => Mesa.fromMap(m as Map<String, dynamic>))
            .toList(),
        fechaCreacion: map['fechaCreacion'] != null
            ? (map['fechaCreacion'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'tenantId': tenantId,
        'nombre': nombre,
        'descripcion': descripcion,
        'activo': activo,
        'mesas': mesas.map((m) => m.toMap()).toList(),
        'fechaCreacion': fechaCreacion != null
            ? Timestamp.fromDate(fechaCreacion!)
            : FieldValue.serverTimestamp(),
      };

  Salon copyWith({
    String? id,
    String? tenantId,
    String? nombre,
    String? descripcion,
    bool? activo,
    List<Mesa>? mesas,
    DateTime? fechaCreacion,
  }) =>
      Salon(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        activo: activo ?? this.activo,
        mesas: mesas ?? this.mesas,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      );
}
