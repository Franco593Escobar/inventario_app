import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/usuario_bios.dart';

class UsuarioBiosRepository {
  UsuarioBiosRepository()
      : _col = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        ).collection('usuario_bios');

  final CollectionReference<Map<String, dynamic>> _col;

  // ── Lectura en tiempo real ───────────────────────────────
  Stream<List<UsuarioBios>> watchAll() {
    return _col.orderBy('identificador').snapshots().map(
          (snap) => snap.docs
              .map((d) => UsuarioBios.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ── Obtener el usuario BIOS activo actual ────────────────
  Future<UsuarioBios?> getActivo() async {
    final snap = await _col.where('activo', isEqualTo: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return UsuarioBios.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  // ── Crear / Actualizar — devuelve el id del documento ────
  Future<String> save(UsuarioBios usuario) async {
    final data = usuario
        .copyWith(
          fechaCreacion: usuario.fechaCreacion ?? DateTime.now(),
        )
        .toMap();

    if (usuario.id.isEmpty) {
      final ref = await _col.add(data);
      return ref.id;
    } else {
      await _col.doc(usuario.id).set(data, SetOptions(merge: true));
      return usuario.id;
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

    final activos = await _col.where('activo', isEqualTo: true).get();
    for (final doc in activos.docs) {
      if (doc.id != id) {
        batch.update(doc.reference, {'activo': false});
      }
    }
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
