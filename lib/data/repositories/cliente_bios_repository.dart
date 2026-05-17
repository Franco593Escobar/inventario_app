import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/cliente_bios.dart';

class ClienteBiosRepository {
  ClienteBiosRepository()
      : _col = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        ).collection('cliente_bios');

  final CollectionReference<Map<String, dynamic>> _col;

  // ── Lectura en tiempo real ───────────────────────────────
  Stream<List<ClienteBios>> watchAll() {
    return _col.orderBy('identificador').snapshots().map(
          (snap) => snap.docs
              .map((d) => ClienteBios.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ── Obtener el cliente activo actual ─────────────────────
  Future<ClienteBios?> getActivo() async {
    final snap = await _col.where('activo', isEqualTo: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return ClienteBios.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  // ── Crear / Actualizar ───────────────────────────────────
  Future<void> save(ClienteBios cliente) async {
    final data = cliente
        .copyWith(
          fechaCreacion: cliente.fechaCreacion ?? DateTime.now(),
        )
        .toMap();

    if (cliente.id.isEmpty) {
      await _col.add(data);
    } else {
      await _col.doc(cliente.id).set(data, SetOptions(merge: true));
    }
  }

  // ── Eliminar ─────────────────────────────────────────────
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  // ── Seleccionar como activo ──────────────────────────────
  /// Pone activo=true en [id] y activo=false en todos los demás.
  Future<void> setActivo(String id) async {
    final batch = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseURL: 'inventario-bdd',
    ).batch();

    // Desactivar todos los que están activos ahora
    final activos = await _col.where('activo', isEqualTo: true).get();
    for (final doc in activos.docs) {
      if (doc.id != id) {
        batch.update(doc.reference, {'activo': false});
      }
    }

    // Activar el nuevo
    batch.update(_col.doc(id), {'activo': true});

    await batch.commit();
  }

  // ── Desactivar todos ─────────────────────────────────────
  Future<void> clearActivo() async {
    final batch = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseURL: 'inventario-bdd',
    ).batch();
    final activos = await _col.where('activo', isEqualTo: true).get();
    for (final doc in activos.docs) {
      batch.update(doc.reference, {'activo': false});
    }
    await batch.commit();
  }
}
