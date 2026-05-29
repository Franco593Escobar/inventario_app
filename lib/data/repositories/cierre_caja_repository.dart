import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/cierre_caja.dart';

class CierreCajaRepository {
  CierreCajaRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('cierres_caja');

  /// Stream de los últimos 50 cierres del tenant, ordenados por fecha DESC.
  Stream<List<CierreCaja>> watchByTenant(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('fecha_cierre', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CierreCaja.fromMap(d.id, d.data())).toList());
  }

  /// Guarda un nuevo cierre de caja.
  Future<void> guardar(CierreCaja cierre) async {
    await _col.add(cierre.toMap());
  }
}
