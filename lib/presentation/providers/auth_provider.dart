import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/repositories/cliente_bios_repository.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.uninitialized;
  String _nombreUsuario = '';
  String _rol = '';
  String _uid = '';
  String _tenantNombre = '';
  String _sucursalNombre = '';
  String _tipoComercio = 'comercio';
  String _errorMessage = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseURL: 'inventario-bdd',
  );

  AuthStatus get status => _status;
  String get nombreUsuario => _nombreUsuario;
  String get rol => _rol;
  String get uid => _uid;
  String get tenantNombre => _tenantNombre;
  String get sucursalNombre => _sucursalNombre;
  String get tipoComercio => _tipoComercio;
  String get errorMessage => _errorMessage;

  String _normalizeValue(String value) => value.trim().toLowerCase();

  String _readFirstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

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
        _tenantNombre = _readFirstNonEmpty(userData, const [
          'empresa_nombre',
          'negocio_nombre',
          'tenant_nombre',
        ]);
        _sucursalNombre = _readFirstNonEmpty(userData, const [
          'sucursal_nombre',
          'sucursal',
          'bodega_nombre',
        ]);
        // Leer el cliente BIOS activo para obtener nombre de negocio y tipo
        try {
          final clienteActivo = await ClienteBiosRepository().getActivo();
          if (clienteActivo != null) {
            _tenantNombre = clienteActivo.nombreNegocio;
            _tipoComercio = clienteActivo.tipoComercio;
            _sucursalNombre = _sucursalNombre.isNotEmpty
                ? _sucursalNombre
                : clienteActivo.nombreNegocio;
          }
        } catch (_) {
          // Si Firestore falla al leer cliente_bios, usa fallback del usuario
        }
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
    _tenantNombre = '';
    _sucursalNombre = '';
    _tipoComercio = 'comercio';
    notifyListeners();
  }
}
