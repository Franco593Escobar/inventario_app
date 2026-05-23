import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/venta.dart';

class VentaRepository {
  VentaRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ventas');

  Stream<List<Venta>> watchByTenant(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('fecha', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map((d) => Venta.fromMap(d.id, d.data())).toList());
  }

  /// Registra la venta y decrementa el stock de cada producto en un batch.
  Future<void> create(Venta venta) async {
    final batch = _firestore.batch();
    final ventaRef = _col.doc();
    batch.set(ventaRef, venta.toMap());
    final prodCol = _firestore.collection('productos');
    for (final item in venta.items) {
      batch.update(prodCol.doc(item.productoId), {
        'stock': FieldValue.increment(-(item.cantidad.toInt())),
      });
    }
    await batch.commit();
  }

  Future<void> anular(String ventaId) async {
    await _col.doc(ventaId).update({'estado': 'anulada'});
  }
}
