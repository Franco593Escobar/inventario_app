import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/proveedor.dart';

class ProveedorRepository {
  ProveedorRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('proveedores');

  Stream<List<Proveedor>> watchByTenant(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('nombre')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Proveedor.fromMap(d.id, d.data())).toList());
  }

  Future<void> create(Proveedor p) async {
    await _col.add(p
        .copyWith(id: '', fechaCreacion: p.fechaCreacion ?? DateTime.now())
        .toMap());
  }

  Future<void> update(Proveedor p) async {
    await _col.doc(p.id).update(p.toMap());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
