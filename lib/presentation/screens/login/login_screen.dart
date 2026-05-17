import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

/// Nombre del cliente que contrata el servicio.
/// Actualizar cuando se implemente el módulo de Configuración multi-tenant.
const _kTenantNombre = 'Grupo Ramones';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _intentarIngresar() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final exito = await authProvider.login(
      _usuarioController.text.trim(),
      _passController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (exito) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido, ${auth.nombreUsuario}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final msg = auth.errorMessage.isNotEmpty
          ? 'Error: ${auth.errorMessage}'
          : 'Credenciales incorrectas o usuario inactivo';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 960;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                child: _buildShowcasePanel(),
                              ),
                              Expanded(
                                child: _buildLoginPanel(),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildShowcasePanel(compact: true),
                              _buildLoginPanel(),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShowcasePanel({bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 28 : 42),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Centro de Operación Multinegocio',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Accede a Usuarios, Productos, Inventario y Ventas desde una Interfaz pensada para Web y Operación Comercial.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LoginFeatureChip(label: 'Dashboard Ejecutivo'),
              _LoginFeatureChip(label: 'CRUD Administrativo'),
              _LoginFeatureChip(label: 'Web + Android'),
            ],
          ),

          // ── Branding footer ────────────────────────────────────
          const SizedBox(height: 36),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 16),
          const Text(
            'BIOS Soluciones Informáticas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Since 2026',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\u00ae By $_kTenantNombre - Todos los Derechos Reservados \u00a9',
            style: TextStyle(
              color: Colors.white.withOpacity(0.52),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ingresar al sistema',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa tus credenciales para continuar con la gestión del negocio.',
            style: TextStyle(color: Colors.blueGrey.shade700, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _usuarioController,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              hintText: 'Ingresa tu usuario',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _passController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contrasena',
              hintText: 'Ingresa tu contrasena',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _intentarIngresar,
                    child: const Text('Ingresar'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoginFeatureChip extends StatelessWidget {
  const _LoginFeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
