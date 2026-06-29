import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inventario_app/data/models/marca_bios.dart';
import 'package:inventario_app/data/models/usuario_bios.dart';
import 'package:inventario_app/data/repositories/usuario_bios_repository.dart';
import 'package:inventario_app/data/repositories/marca_bios_repository.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.uninitialized;
  String _nombreUsuario = '';
  String _loginUsername = '';
  String _rol = '';
  String _uid = '';
  String _tenantId = '';
  String _tenantNombre = '';
  String _sucursalNombre = '';
  String _tipoComercio = 'comercio';
  String _errorMessage = '';
  String _sessionPassword = '';
  // ── Colores de la marca del tenant ──
  String _marcaColorPrimario = '';
  String? _marcaLogoBase64;
  List<String> _marcaCromatica = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseURL: 'inventario-bdd',
  );

  AuthStatus get status => _status;
  String get nombreUsuario => _nombreUsuario;

  /// Nombre de usuario de login (ej. "593bk-gramon") — usado para auditoría y lookup de tenant.
  String get loginUsername => _loginUsername;
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

  bool validateCurrentPassword(String password) {
    final input = password.trim();
    return _sessionPassword.isNotEmpty && _sessionPassword == input;
  }

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

  List<String> _candidateEmails(String usuario) {
    final trimmed = usuario.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    if (trimmed.contains('@')) return [trimmed];
    return ['${trimmed}@liris.local', '${trimmed}@inventario.app'];
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Correo inválido.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'Usuario/correo no encontrado.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta de nuevo en unos minutos.';
      case 'network-request-failed':
        return 'Error de red al autenticar.';
      default:
        return e.message ?? e.code;
    }
  }

  Future<bool> login(String usuario, String password) async {
    _errorMessage = '';
    try {
      final pass = password.trim();
      final trimmedUsuario = usuario.trim().toLowerCase();

      if (pass.isEmpty) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Ingresa una contraseña válida.';
        notifyListeners();
        return false;
      }

      if (trimmedUsuario.isEmpty) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Ingresa un usuario o correo válido.';
        notifyListeners();
        return false;
      }

      // Intentar autenticación directa con Firebase Auth
      UserCredential? credential;
      String? lastAuthError;

      // Si el usuario ingresó un email completo, usarlo directamente
      if (trimmedUsuario.contains('@')) {
        try {
          credential = await _auth.signInWithEmailAndPassword(
            email: trimmedUsuario,
            password: pass,
          );
        } on FirebaseAuthException catch (e) {
          lastAuthError = _friendlyAuthError(e);
        }
      } else {
        // Si no tiene @, intentar con los dominios conocidos
        final candidates = _candidateEmails(usuario);

        for (final email in candidates) {
          try {
            credential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: pass,
            );
            break;
          } on FirebaseAuthException catch (e) {
            lastAuthError = _friendlyAuthError(e);
          }
        }
      }

      // Si Firebase Auth falla, intentar autenticación local contra Firestore
      if (credential == null || credential.user == null) {
        debugPrint('[Liris] ⚠️ Firebase Auth falló, intentando auth local...');

        // Buscar usuario en Firestore por nombre_usuario o email
        QuerySnapshot<Map<String, dynamic>> userQuery;
        try {
          // Intento 1: buscar por nombre_usuario
          userQuery = await _firestore
              .collection('usuarios')
              .where('nombre_usuario', isEqualTo: trimmedUsuario)
              .limit(1)
              .get();

          // Intento 2: buscar por email si no se encontró por nombre_usuario
          if (userQuery.docs.isEmpty && trimmedUsuario.contains('@')) {
            userQuery = await _firestore
                .collection('usuarios')
                .where('email', isEqualTo: trimmedUsuario)
                .limit(1)
                .get();
          }

          if (userQuery.docs.isEmpty) {
            _status = AuthStatus.unauthenticated;
            _errorMessage = lastAuthError ?? 'Usuario/correo no encontrado.';
            debugPrint('[Liris] ❌ LOGIN FALLIDO: $_errorMessage');
            notifyListeners();
            return false;
          }

          final userDoc = userQuery.docs.first;
          final userData = userDoc.data();

          // Verificar contraseña almacenada en Firestore
          final storedPassword = userData['password']?.toString().trim() ?? '';
          if (storedPassword.isEmpty || storedPassword != pass) {
            _status = AuthStatus.unauthenticated;
            _errorMessage = 'Contraseña incorrecta.';
            debugPrint('[Liris] ❌ LOGIN FALLIDO: Contraseña incorrecta');
            notifyListeners();
            return false;
          }

          // Verificar estado activo
          final activo = userData['estado_activo'] ?? false;
          if (!activo) {
            _status = AuthStatus.unauthenticated;
            _errorMessage = 'El usuario "$usuario" está inactivo';
            debugPrint('[Liris] ❌ LOGIN FALLIDO: Usuario inactivo');
            notifyListeners();
            return false;
          }

          // Usuario autenticado localmente - usar el UID del documento
          debugPrint('[Liris] ✅ Auth local exitosa para: $trimmedUsuario');
          _processUserData(userDoc.id, userData, usuario, pass);
          return true;
        } catch (e) {
          debugPrint('[Liris] ERROR en auth local: $e');
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Error al autenticar. Intenta de nuevo.';
          notifyListeners();
          return false;
        }
      }

      final authUser = credential.user!;
      final userSnap =
          await _firestore.collection('usuarios').doc(authUser.uid).get();

      if (!userSnap.exists) {
        await _auth.signOut();
        _status = AuthStatus.unauthenticated;
        _errorMessage =
            'No existe perfil usuarios/{uid} para este usuario autenticado. Solicita migración de perfil.';
        notifyListeners();
        return false;
      }

      final userData = userSnap.data()!;
      final activo = userData['estado_activo'] ?? false;
      if (!activo) {
        await _auth.signOut();
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'El usuario "$usuario" está inactivo';
        notifyListeners();
        return false;
      }

      _processUserData(authUser.uid, userData, usuario, pass);
      return true;

      // Buscar tenant_id con varias posibles claves (snake_case y camelCase)
      _tenantId = _readFirstNonEmpty(userData, const [
        'tenant_id',
        'tenantId',
        'negocio_id',
        'negocioId',
        'cedula_negocio',
        'ruc_negocio',
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

      // ── Cargar datos del negocio desde usuario_bios ──
      if (_tenantId.isNotEmpty) {
        try {
          // Intento 1: buscar por document ID (= cédula del negocio)
          UsuarioBios? negocio =
              await UsuarioBiosRepository().getById(_tenantId);

          // Intento 2: buscar por campo 'cedula'
          negocio ??= await UsuarioBiosRepository().getByCedula(_tenantId);

          if (negocio != null) {
            _tenantId = negocio.id; // asegurar que usamos el doc ID real
            _tenantNombre = negocio.nombreNegocio;
            _tipoComercio = negocio.tipoComercio;
            if (_sucursalNombre.isEmpty)
              _sucursalNombre = negocio.nombreNegocio;
          }
          debugPrint(
              '[Liris] usuario_bios → tenantId=$_tenantId | negocio=${negocio?.nombreNegocio ?? "NO ENCONTRADO"}');
        } catch (e) {
          debugPrint('[Liris] ERROR cargando usuario_bios: $e');
        }
      } else {
        debugPrint(
            '[Liris] ADVERTENCIA: tenant_id vacío para usuario=$usuario. Verifica el doc en colección "usuarios".');
      }

      // ── Fallback: si aún sin tenantNombre, buscar en usuario_bios por nombre ──
      if (_tenantNombre.isNotEmpty && _tenantId.isEmpty) {
        try {
          final negocio =
              await UsuarioBiosRepository().getByNombreNegocio(_tenantNombre);
          if (negocio != null) {
            _tenantId = negocio.id;
            _tenantNombre = negocio.nombreNegocio;
            _tipoComercio = negocio.tipoComercio;
            debugPrint('[Liris] fallback nombre → tenantId=$_tenantId');
          }
        } catch (_) {}
      }

      // ── Fallback por creado_por: hereda negocio del admin que creó el usuario ──
      if (_tenantId.isEmpty) {
        final creadoPor = userData['creado_por']?.toString().trim() ?? '';
        if (creadoPor.isNotEmpty) {
          try {
            final negocio =
                await UsuarioBiosRepository().getByNombreUsuario(creadoPor);
            if (negocio != null) {
              _tenantId = negocio.id;
              _tenantNombre = negocio.nombreNegocio;
              _tipoComercio = negocio.tipoComercio;
              if (_sucursalNombre.isEmpty)
                _sucursalNombre = negocio.nombreNegocio;
              debugPrint(
                  '[Liris] ✅ fallback creado_por="$creadoPor" → tenantId=$_tenantId | negocio=$_tenantNombre');
            } else {
              debugPrint(
                  '[Liris] creado_por="$creadoPor" no encontrado en usuario_bios');
            }
          } catch (_) {}
        }
      }

      // ── Fallback final: buscar usuario_bios por nombre_usuario del login ──
      if (_tenantId.isEmpty) {
        try {
          final negocio =
              await UsuarioBiosRepository().getByNombreUsuario(usuario.trim());
          if (negocio != null) {
            _tenantId = negocio.id;
            _tenantNombre = negocio.nombreNegocio;
            _tipoComercio = negocio.tipoComercio;
            if (_sucursalNombre.isEmpty)
              _sucursalNombre = negocio.nombreNegocio;
            debugPrint(
                '[Liris] ✅ fallback por nombre_usuario → tenantId=$_tenantId | negocio=$_tenantNombre');
          } else {
            debugPrint(
                '[Liris] ❌ Sin vínculo al negocio. Agrega tenant_id="${negocio?.id ?? "ID_NEGOCIO"}" al doc de usuario=$usuario en Firestore → colección "usuarios"');
          }
        } catch (_) {}
      }

      // ── Cargar marca del tenant (por ID y fallback por nombre) ──
      if (_tenantId.isNotEmpty) {
        try {
          MarcaBios? marca =
              await MarcaBiosRepository().getByNegocioId(_tenantId);
          if (marca == null && _tenantNombre.isNotEmpty) {
            debugPrint(
                '[Liris] marca no encontrada por ID, buscando por nombre: $_tenantNombre');
            marca =
                await MarcaBiosRepository().getByNombreNegocio(_tenantNombre);
          }
          if (marca != null) {
            _marcaColorPrimario = marca.colorPrimario;
            _marcaLogoBase64 = marca.logoBase64;
            _marcaCromatica = marca.cromatica;
            debugPrint('[Liris] ✅ marca cargada: color=${marca.colorPrimario}');
          } else {
            debugPrint(
                '[Liris] ❌ marca NO encontrada para tenantId=$_tenantId / nombre=$_tenantNombre');
          }
        } catch (e) {
          debugPrint('[Liris] ERROR cargando marca_bios: $e');
        }
      }

      // ── Superadmin: cargar nombre del cliente activo si no tiene tenant ──
      if (_rol.toLowerCase() == 'superadmin' && _tenantNombre.isEmpty) {
        try {
          final clienteActivo = await UsuarioBiosRepository().getActivo();
          if (clienteActivo != null) {
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

  Future<void> _processUserData(String uid, Map<String, dynamic> userData,
      String usuario, String pass) async {
    _uid = uid;
    _loginUsername = _readFirstNonEmpty(
      userData,
      const ['login_username', 'nombre_usuario'],
    );
    if (_loginUsername.isEmpty) {
      _loginUsername = usuario.trim();
    }
    _nombreUsuario = _readFirstNonEmpty(
        userData, const ['nombres', 'nombre_usuario', 'apellidos']);
    _rol = userData['rol'] ?? 'vendedor';
    _sessionPassword = pass;

    // Buscar tenant_id con varias posibles claves (snake_case y camelCase)
    _tenantId = _readFirstNonEmpty(userData, const [
      'tenant_id',
      'tenantId',
      'negocio_id',
      'negocioId',
      'cedula_negocio',
      'ruc_negocio',
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

    // ── Cargar datos del negocio desde usuario_bios ──
    if (_tenantId.isNotEmpty) {
      try {
        // Intento 1: buscar por document ID (= cédula del negocio)
        UsuarioBios? negocio = await UsuarioBiosRepository().getById(_tenantId);

        // Intento 2: buscar por campo 'cedula'
        negocio ??= await UsuarioBiosRepository().getByCedula(_tenantId);

        if (negocio != null) {
          _tenantId = negocio.id; // asegurar que usamos el doc ID real
          _tenantNombre = negocio.nombreNegocio;
          _tipoComercio = negocio.tipoComercio;
          if (_sucursalNombre.isEmpty) _sucursalNombre = negocio.nombreNegocio;
        }
        debugPrint(
            '[Liris] usuario_bios → tenantId=$_tenantId | negocio=${negocio?.nombreNegocio ?? "NO ENCONTRADO"}');
      } catch (e) {
        debugPrint('[Liris] ERROR cargando usuario_bios: $e');
      }
    } else {
      debugPrint(
          '[Liris] ADVERTENCIA: tenant_id vacío para usuario=$usuario. Verifica el doc en colección "usuarios".');
    }

    // ── Fallback: si aún sin tenantNombre, buscar en usuario_bios por nombre ──
    if (_tenantNombre.isNotEmpty && _tenantId.isEmpty) {
      try {
        final negocio =
            await UsuarioBiosRepository().getByNombreNegocio(_tenantNombre);
        if (negocio != null) {
          _tenantId = negocio.id;
          _tenantNombre = negocio.nombreNegocio;
          _tipoComercio = negocio.tipoComercio;
          debugPrint('[Liris] fallback nombre → tenantId=$_tenantId');
        }
      } catch (_) {}
    }

    // ── Fallback por creado_por: hereda negocio del admin que creó el usuario ──
    if (_tenantId.isEmpty) {
      final creadoPor = userData['creado_por']?.toString().trim() ?? '';
      if (creadoPor.isNotEmpty) {
        try {
          final negocio =
              await UsuarioBiosRepository().getByNombreUsuario(creadoPor);
          if (negocio != null) {
            _tenantId = negocio.id;
            _tenantNombre = negocio.nombreNegocio;
            _tipoComercio = negocio.tipoComercio;
            if (_sucursalNombre.isEmpty)
              _sucursalNombre = negocio.nombreNegocio;
            debugPrint(
                '[Liris] ✅ fallback creado_por="$creadoPor" → tenantId=$_tenantId | negocio=$_tenantNombre');
          } else {
            debugPrint(
                '[Liris] creado_por="$creadoPor" no encontrado en usuario_bios');
          }
        } catch (_) {}
      }
    }

    // ── Fallback final: buscar usuario_bios por nombre_usuario del login ──
    if (_tenantId.isEmpty) {
      try {
        final negocio =
            await UsuarioBiosRepository().getByNombreUsuario(usuario.trim());
        if (negocio != null) {
          _tenantId = negocio.id;
          _tenantNombre = negocio.nombreNegocio;
          _tipoComercio = negocio.tipoComercio;
          if (_sucursalNombre.isEmpty) _sucursalNombre = negocio.nombreNegocio;
          debugPrint(
              '[Liris] ✅ fallback por nombre_usuario → tenantId=$_tenantId | negocio=$_tenantNombre');
        } else {
          debugPrint(
              '[Liris] ❌ Sin vínculo al negocio. Agrega tenant_id="${negocio?.id ?? "ID_NEGOCIO"}" al doc de usuario=$usuario en Firestore → colección "usuarios"');
        }
      } catch (_) {}
    }

    // ── Cargar marca del tenant (por ID y fallback por nombre) ──
    if (_tenantId.isNotEmpty) {
      try {
        MarcaBios? marca =
            await MarcaBiosRepository().getByNegocioId(_tenantId);
        if (marca == null && _tenantNombre.isNotEmpty) {
          debugPrint(
              '[Liris] marca no encontrada por ID, buscando por nombre: $_tenantNombre');
          marca = await MarcaBiosRepository().getByNombreNegocio(_tenantNombre);
        }
        if (marca != null) {
          _marcaColorPrimario = marca.colorPrimario;
          _marcaLogoBase64 = marca.logoBase64;
          _marcaCromatica = marca.cromatica;
          debugPrint('[Liris] ✅ marca cargada: color=${marca.colorPrimario}');
        } else {
          debugPrint(
              '[Liris] ❌ marca NO encontrada para tenantId=$_tenantId / nombre=$_tenantNombre');
        }
      } catch (e) {
        debugPrint('[Liris] ERROR cargando marca_bios: $e');
      }
    }

    // ── Superadmin: cargar nombre del cliente activo si no tiene tenant ──
    if (_rol.toLowerCase() == 'superadmin' && _tenantNombre.isEmpty) {
      try {
        final clienteActivo = await UsuarioBiosRepository().getActivo();
        if (clienteActivo != null) {
          _tenantNombre = clienteActivo.nombreNegocio;
          _tipoComercio = clienteActivo.tipoComercio;
        }
      } catch (_) {}
    }

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void logout() {
    _auth.signOut();
    _status = AuthStatus.unauthenticated;
    _nombreUsuario = '';
    _loginUsername = '';
    _rol = '';
    _uid = '';
    _tenantId = '';
    _tenantNombre = '';
    _sucursalNombre = '';
    _tipoComercio = 'comercio';
    _sessionPassword = '';
    _marcaColorPrimario = '';
    _marcaLogoBase64 = null;
    _marcaCromatica = [];
    notifyListeners();
  }
}
