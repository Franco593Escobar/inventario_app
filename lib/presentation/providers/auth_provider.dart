import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.uninitialized;
  String _nombreUsuario = '';
  String _rol = '';
  String _uid = '';
  String _errorMessage = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseURL: 'inventario-bdd',
  );

  AuthStatus get status => _status;
  String get nombreUsuario => _nombreUsuario;
  String get rol => _rol;
  String get uid => _uid;
  String get errorMessage => _errorMessage;

  String _normalizeValue(String value) => value.trim().toLowerCase();

  Future<bool> login(String usuario, String password) async {
    _errorMessage = '';
    try {
      final normalizedUsuario = _normalizeValue(usuario);

      QuerySnapshot<Map<String, dynamic>> query = await _firestore
          .collection('usuarios')
          .where('nombre_usuario', isEqualTo: usuario.trim())
          .get();

      if (query.docs.isEmpty) {
        final allUsers = await _firestore.collection('usuarios').get();
        final matchingDocs = allUsers.docs.where((doc) {
          final storedUser = (doc.data()['nombre_usuario'] ?? '').toString();
          return _normalizeValue(storedUser) == normalizedUsuario;
        }).toList();

        if (matchingDocs.isNotEmpty) {
          query = FakeQuerySnapshot(matchingDocs);
        }
      }

      if (query.docs.isEmpty) {
        _status = AuthStatus.unauthenticated;
        final allUsers = await _firestore.collection('usuarios').get();
        final visibleUsers = allUsers.docs
            .map(
                (doc) => (doc.data()['nombre_usuario'] ?? '').toString().trim())
            .where((value) => value.isNotEmpty)
            .toList();
        final sampleUsers = visibleUsers.take(5).join(', ');
        _errorMessage = visibleUsers.isEmpty
            ? 'Usuario "$usuario" no encontrado. La app no ve usuarios en la colección.'
            : 'Usuario "$usuario" no encontrado. Usuarios visibles: $sampleUsers';
        notifyListeners();
        return false;
      }

      final userData = query.docs.first.data();
      final activo = userData['estado_activo'] ?? false;
      if (!activo) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'El usuario "$usuario" está inactivo';
        notifyListeners();
        return false;
      }

      if (userData['password'] == password.trim()) {
        _uid = query.docs.first.id;
        _nombreUsuario =
            userData['nombres'] ?? userData['nombre_usuario'] ?? '';
        _rol = userData['rol'] ?? 'vendedor';
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Contraseña incorrecta para el usuario "$usuario"';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _status = AuthStatus.unauthenticated;
    _nombreUsuario = '';
    _rol = '';
    _uid = '';
    notifyListeners();
  }
}

class FakeQuerySnapshot extends QuerySnapshot<Map<String, dynamic>> {
  FakeQuerySnapshot(this._docs);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges =>
      throw UnimplementedError();

  @override
  int get size => _docs.length;
}
