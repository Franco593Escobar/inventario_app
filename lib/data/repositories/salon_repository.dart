import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/salon.dart';

class SalonRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseURL: 'inventario-bdd',
      );

  CollectionReference<Map<String, dynamic>> _col(String tenantId) =>
      _db.collection('tenants').doc(tenantId).collection('salones');

  /// Stream de salones activos del tenant
  Stream<List<Salon>> watchByTenant(String tenantId) {
    return _col(tenantId)
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Salon.fromMap(d.id, d.data())).toList());
  }

  /// Obtener todos (incluyendo inactivos) — para la pantalla de config
  Stream<List<Salon>> watchAllByTenant(String tenantId) {
    return _col(tenantId).orderBy('nombre').snapshots().map(
        (snap) => snap.docs.map((d) => Salon.fromMap(d.id, d.data())).toList());
  }

  Future<Salon> create(Salon salon) async {
    final ref = await _col(salon.tenantId).add(salon.toMap());
    final snap = await ref.get();
    return Salon.fromMap(snap.id, snap.data()!);
  }

  Future<void> update(Salon salon) async {
    await _col(salon.tenantId).doc(salon.id).update(salon.toMap());
  }

  Future<void> delete(String tenantId, String salonId) async {
    await _col(tenantId).doc(salonId).update({'activo': false});
  }

  Future<Salon?> getById(String tenantId, String salonId) async {
    final snap = await _col(tenantId).doc(salonId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Salon.fromMap(snap.id, snap.data()!);
  }
}
