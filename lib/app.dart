import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/screens/dashboard/superadmin_dashboard_screen.dart';
import 'package:inventario_app/presentation/screens/login/login_screen.dart';

class InventarioApp extends StatelessWidget {
  const InventarioApp({super.key});

  Widget _buildAuthenticatedHome(AuthProvider auth) {
    switch (auth.rol.toLowerCase()) {
      case 'superadmin':
        return SuperadminDashboardScreen(
          nombreUsuario: auth.nombreUsuario,
          tenantNombre: auth.tenantNombre,
          sucursalNombre: auth.sucursalNombre,
          tipoComercio: auth.tipoComercio,
          rol: auth.rol,
          onLogout: auth.logout,
        );
      default:
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('Inventario'),
            actions: [
              IconButton(
                onPressed: auth.logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bienvenido, ${auth.nombreUsuario}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rol: ${auth.rol}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventario',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.status == AuthStatus.authenticated) {
            return _buildAuthenticatedHome(auth);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
