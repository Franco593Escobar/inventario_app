import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/movimiento_inventario.dart';

class MovimientoInventarioRepository {
  MovimientoInventarioRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('movimientos_inventario');

  Stream<List<MovimientoInventario>> watchByTenant(String tenantId) {
    // Superadmin (tenant_id = "global") ve todos los movimientos sin restricción
    if (tenantId == 'global') {
      return _col.orderBy('fecha', descending: true).limit(200).snapshots().map(
          (s) => s.docs
              .map((d) => MovimientoInventario.fromMap(d.id, d.data()))
              .toList());
    }
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('fecha', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MovimientoInventario.fromMap(d.id, d.data()))
            .toList());
  }

  /// Registra el movimiento y actualiza el stock del producto en un batch.
  Future<void> registrar(MovimientoInventario mov, int nuevoStock) async {
    final batch = _firestore.batch();
    batch.set(_col.doc(), mov.toMap());
    batch.update(_firestore.collection('productos').doc(mov.productoId), {
      'stock': nuevoStock,
    });
    await batch.commit();
  }
}
