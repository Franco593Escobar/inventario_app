import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/cliente.dart';

class ClienteRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseURL: 'inventario-bdd',
      );

  CollectionReference<Map<String, dynamic>> _col(String tenantId) =>
      _db.collection('tenants').doc(tenantId).collection('clientes');

  /// Stream de clientes activos del tenant
  Stream<List<Cliente>> watchByTenant(String tenantId) {
    return _col(tenantId)
        .where('activo', isEqualTo: true)
        .orderBy('nombres')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Cliente.fromMap(d.id, d.data())).toList());
  }

  Future<Cliente> create(Cliente cliente) async {
    final ref = await _col(cliente.tenantId).add(cliente.toMap());
    final snap = await ref.get();
    return Cliente.fromMap(snap.id, snap.data()!);
  }

  Future<void> update(Cliente cliente) async {
    await _col(cliente.tenantId).doc(cliente.id).update(cliente.toMap());
  }

  Future<void> delete(String tenantId, String clienteId) async {
    await _col(tenantId).doc(clienteId).update({'activo': false});
  }

  /// Buscar por número de documento (exacto) o por nombre (prefijo)
  Future<List<Cliente>> buscar(String tenantId, String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Buscar por número de documento
    final byDoc = await _col(tenantId)
        .where('numeroDocumento', isEqualTo: q)
        .limit(10)
        .get();

    if (byDoc.docs.isNotEmpty) {
      return byDoc.docs.map((d) => Cliente.fromMap(d.id, d.data())).toList();
    }

    // Buscar por nombre (range query)
    final byNombre = await _col(tenantId)
        .where('nombres', isGreaterThanOrEqualTo: q)
        .where('nombres', isLessThan: '${q}z')
        .limit(10)
        .get();

    return byNombre.docs.map((d) => Cliente.fromMap(d.id, d.data())).toList();
  }
}
