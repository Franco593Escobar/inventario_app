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

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserDocument(
    String usuario,
  ) async {
    final normalizedUsuario = _normalizeValue(usuario);

    final exactMatch = await _firestore
        .collection('usuarios')
        .where('nombre_usuario', isEqualTo: usuario.trim())
        .limit(1)
        .get();

    if (exactMatch.docs.isNotEmpty) {
      return exactMatch.docs.first;
    }

    final allUsers = await _firestore.collection('usuarios').get();
    for (final doc in allUsers.docs) {
      final storedUser = (doc.data()['nombre_usuario'] ?? '').toString();
      if (_normalizeValue(storedUser) == normalizedUsuario) {
        return doc;
      }
    }

    return null;
  }

  Future<bool> login(String usuario, String password) async {
    _errorMessage = '';
    try {
      final userDoc = await _findUserDocument(usuario);
      if (userDoc == null) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Usuario "$usuario" no encontrado';
        notifyListeners();
        return false;
      }

      final userData = userDoc.data();
      final activo = userData['estado_activo'] ?? false;
      if (!activo) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'El usuario "$usuario" está inactivo';
        notifyListeners();
        return false;
      }

      if (userData['password'] == password.trim()) {
        _uid = userDoc.id;
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
