import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/marca_bios.dart';

class MarcaBiosRepository {
  MarcaBiosRepository()
      : _col = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        ).collection('marca_bios');

  final CollectionReference<Map<String, dynamic>> _col;

  // ── Lectura en tiempo real ───────────────────────────────
  Stream<List<MarcaBios>> watchAll() {
    return _col.orderBy('nombreNegocio').snapshots().map(
          (snap) =>
              snap.docs.map((d) => MarcaBios.fromMap(d.id, d.data())).toList(),
        );
  }

  // ── Obtener por negocio (por ID) ────────────────────────
  Future<MarcaBios?> getByNegocioId(String negocioId) async {
    final snap =
        await _col.where('negocioId', isEqualTo: negocioId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return MarcaBios.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  // ── Fallback: buscar por nombre del negocio ───────────────
  Future<MarcaBios?> getByNombreNegocio(String nombre) async {
    if (nombre.trim().isEmpty) return null;
    final snap = await _col
        .where('nombreNegocio', isEqualTo: nombre.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return MarcaBios.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  // ── Crear / Actualizar ───────────────────────────────────
  Future<String> save(MarcaBios marca) async {
    final data = marca
        .copyWith(fechaCreacion: marca.fechaCreacion ?? DateTime.now())
        .toMap();

    if (marca.id.isEmpty) {
      final ref = await _col.add(data);
      return ref.id;
    } else {
      await _col.doc(marca.id).set(data, SetOptions(merge: true));
      return marca.id;
    }
  }

  // ── Eliminar ─────────────────────────────────────────────
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
