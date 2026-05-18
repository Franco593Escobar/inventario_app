import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/seccion.dart';

class SeccionRepository {
  SeccionRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('secciones');

  Stream<List<Seccion>> watchByTenant(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('posicion')
        .snapshots()
        .map(
            (s) => s.docs.map((d) => Seccion.fromMap(d.id, d.data())).toList());
  }

  Future<void> create(Seccion s) async {
    await _col.add(s
        .copyWith(id: '', fechaCreacion: s.fechaCreacion ?? DateTime.now())
        .toMap());
  }

  Future<void> update(Seccion s) async {
    await _col.doc(s.id).update(s.toMap());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
