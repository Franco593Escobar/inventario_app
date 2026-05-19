import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/repositories/usuario_bios_repository.dart';
import 'package:inventario_app/data/repositories/marca_bios_repository.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.uninitialized;
  String _nombreUsuario = '';
  String _rol = '';
  String _uid = '';
  String _tenantId = '';
  String _tenantNombre = '';
  String _sucursalNombre = '';
  String _tipoComercio = 'comercio';
  String _errorMessage = '';
  // ── Colores de la marca del tenant ──
  String _marcaColorPrimario = '';
  String? _marcaLogoBase64;
  List<String> _marcaCromatica = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseURL: 'inventario-bdd',
  );

  AuthStatus get status => _status;
  String get nombreUsuario => _nombreUsuario;
  String get rol => _rol;
  String get uid => _uid;
  String get tenantId => _tenantId;
  String get tenantNombre => _tenantNombre;
  String get sucursalNombre => _sucursalNombre;
  String get tipoComercio => _tipoComercio;
  String get errorMessage => _errorMessage;
  String get marcaColorPrimario => _marcaColorPrimario;
  String? get marcaLogoBase64 => _marcaLogoBase64;
  List<String> get marcaCromatica => _marcaCromatica;

  /// Devuelve el Color primario de la marca (o AppColors.primary si no hay).
  Color get marcaPrimaryColor {
    try {
      final h = _marcaColorPrimario.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    } catch (_) {}
    return const Color(0xFF1E2E51);
  }

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

    if (exactMatch.docs.isNotEmpty) return exactMatch.docs.first;

    final allUsers = await _firestore.collection('usuarios').get();
    for (final doc in allUsers.docs) {
      final storedUser = (doc.data()['nombre_usuario'] ?? '').toString();
      if (_normalizeValue(storedUser) == normalizedUsuario) return doc;
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

      if (userData['password'] != password.trim()) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Contraseña incorrecta para el usuario "$usuario"';
        notifyListeners();
        return false;
      }

      _uid = userDoc.id;
      _nombreUsuario = _readFirstNonEmpty(
          userData, const ['nombres', 'nombre_usuario', 'apellidos']);
      _rol = userData['rol'] ?? 'vendedor';
      // Buscar tenant_id con varias posibles claves (snake_case y camelCase)
      _tenantId = _readFirstNonEmpty(userData, const [
        'tenant_id',
        'tenantId',
        'negocio_id',
        'negocioId',
      ]);

      _tenantNombre = _readFirstNonEmpty(userData, const [
        'empresa_nombre',
        'negocio_nombre',
        'tenant_nombre',
        'negocio',
        'nombreNegocio',
      ]);
      _sucursalNombre = _readFirstNonEmpty(userData, const [
        'sucursal_nombre',
        'sucursal',
        'bodega_nombre',
      ]);

      // ── Cargar datos del tenant desde usuario_bios ──
      if (_tenantId.isNotEmpty) {
        try {
          final negocio = await UsuarioBiosRepository().getById(_tenantId);
          if (negocio != null) {
            _tenantNombre = negocio.nombreNegocio;
            _tipoComercio = negocio.tipoComercio;
            if (_sucursalNombre.isEmpty)
              _sucursalNombre = negocio.nombreNegocio;
          }
        } catch (_) {}

        // ── Cargar marca del tenant ──
        try {
          final marca = await MarcaBiosRepository().getByNegocioId(_tenantId);
          if (marca != null) {
            _marcaColorPrimario = marca.colorPrimario;
            _marcaLogoBase64 = marca.logoBase64;
            _marcaCromatica = marca.cromatica;
          }
        } catch (_) {}
      } else if (_rol.toLowerCase() == 'superadmin') {
        // Superadmin sin tenantId: usar datos del cliente activo si hay
        try {
          final clienteActivo = await UsuarioBiosRepository().getActivo();
          if (clienteActivo != null && _tenantNombre.isEmpty) {
            _tenantNombre = clienteActivo.nombreNegocio;
            _tipoComercio = clienteActivo.tipoComercio;
          }
        } catch (_) {}
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
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
    _tenantId = '';
    _tenantNombre = '';
    _sucursalNombre = '';
    _tipoComercio = 'comercio';
    _marcaColorPrimario = '';
    _marcaLogoBase64 = null;
    _marcaCromatica = [];
    notifyListeners();
  }
}
