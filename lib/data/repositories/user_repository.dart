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

  Stream<List<AppUser>> watchUsers() {
    return _usuariosCollection.orderBy('nombre_usuario').snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => AppUser.fromMap(doc.id, doc.data()))
            .toList();
      },
    );
  }

  Future<void> createUser(AppUser user) async {
    await _usuariosCollection.add(
      user
          .copyWith(fechaCreacion: user.fechaCreacion ?? DateTime.now())
          .toMap(),
    );
  }

  Future<void> updateUser(AppUser user) async {
    await _usuariosCollection.doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String userId) async {
    await _usuariosCollection.doc(userId).delete();
  }
}
