import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/app_user.dart';

class UserRepository {
  UserRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usuariosCollection =>
      _firestore.collection('usuarios');

  /// Retorna todos los usuarios (solo superadmin debe usar esto).
  Stream<List<AppUser>> watchUsers() {
    return _usuariosCollection.orderBy('nombre_usuario').snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => AppUser.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Retorna solo los usuarios que pertenecen al tenant indicado.
  Stream<List<AppUser>> watchByTenant(String tenantId) {
    return _usuariosCollection
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('nombre_usuario')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  Future<void> createUser(AppUser user) async {
    final data = user
        .copyWith(fechaCreacion: user.fechaCreacion ?? DateTime.now())
        .toMap();
    data['login_username'] = user.nombreUsuario.trim();
    data['nombre_usuario_lc'] = user.nombreUsuario.trim().toLowerCase();
    await _usuariosCollection.add(data);
  }

  Future<void> updateUser(AppUser user) async {
    final data = user.toMap();
    data['login_username'] = user.nombreUsuario.trim();
    data['nombre_usuario_lc'] = user.nombreUsuario.trim().toLowerCase();
    await _usuariosCollection.doc(user.id).update(data);
  }

  Future<void> deleteUser(String userId) async {
    await _usuariosCollection.doc(userId).delete();
  }
}
