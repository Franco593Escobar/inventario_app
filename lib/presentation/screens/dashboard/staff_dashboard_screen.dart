import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/screens/inventario/inventario_screen.dart';
import 'package:inventario_app/presentation/screens/products/products_management_screen.dart';
import 'package:inventario_app/presentation/screens/ventas/ventas_screen.dart';

/// Dashboard para roles de operación: Cajero, Bodeguero, Mesero.
/// Hereda los colores de marca del negocio al que pertenece el usuario
/// (determinado por el campo `creado_por` de su documento en `usuarios`).
class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({
    super.key,
    required this.nombreUsuario,
    required this.tenantNombre,
    required this.tipoComercio,
    required this.rol,
    required this.onLogout,
  });

  final String nombreUsuario;
  final String tenantNombre;
  final String tipoComercio;
  final String rol;
  final VoidCallback onLogout;

  static String _capitalizarNombre(String nombre) {
    return nombre
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get _tenantLabel {
    final negocio = tenantNombre.trim().isNotEmpty
        ? _capitalizarNombre(tenantNombre.trim())
        : 'Mi Negocio';
    return 'Liris - $negocio';
  }

  IconData get _tenantIcon => switch (tipoComercio) {
        'restaurante' => Icons.restaurant_outlined,
        'comercio' => Icons.store_outlined,
        'kiosko' => Icons.storefront_outlined,
        'farmacia' => Icons.local_pharmacy_outlined,
        'supermercado' => Icons.shopping_cart_outlined,
        _ => Icons.cases_outlined,
      };

  /// Módulos disponibles según el rol de operación.
  List<_StaffModule> _modulesForRole() {
    switch (rol.toLowerCase()) {
      case 'cajero':
        return const [
          _StaffModule(
            title: 'Ventas / Caja',
            subtitle: 'Registra ventas y cobros del turno',
            icon: Icons.point_of_sale_outlined,
            isReady: true,
          ),
          _StaffModule(
            title: 'Productos',
            subtitle: 'Consulta el catálogo disponible',
            icon: Icons.inventory_2_outlined,
            isReady: true,
          ),
        ];
      case 'bodeguero':
        return const [
          _StaffModule(
            title: 'Inventario',
            subtitle: 'Controla stock y movimientos de bodega',
            icon: Icons.warehouse_outlined,
            isReady: true,
          ),
          _StaffModule(
            title: 'Productos',
            subtitle: 'Consulta y actualiza el catálogo',
            icon: Icons.inventory_2_outlined,
            isReady: true,
          ),
        ];
      case 'mesero':
        return const [
          _StaffModule(
            title: 'Pedidos',
            subtitle: 'Toma y gestiona pedidos de mesas',
            icon: Icons.receipt_long_outlined,
            isReady: false,
          ),
          _StaffModule(
            title: 'Mesas',
            subtitle: 'Estado y asignación de mesas',
            icon: Icons.table_restaurant_outlined,
            isReady: false,
          ),
        ];
      default:
        return const [
          _StaffModule(
            title: 'Productos',
            subtitle: 'Consulta el catálogo disponible',
            icon: Icons.inventory_2_outlined,
            isReady: true,
          ),
        ];
    }
  }

  Future<void> _confirmarSalida(
      BuildContext context, VoidCallback callback) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content:
            const Text('¿Estás seguro de que deseas salir de la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (ok == true) callback();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final brandColor = auth.marcaPrimaryColor;
        final logoB64 = auth.marcaLogoBase64;
        final tenantIcon = switch (auth.tipoComercio) {
          'restaurante' => Icons.restaurant_outlined,
          'comercio' => Icons.store_outlined,
          'kiosko' => Icons.storefront_outlined,
          'farmacia' => Icons.local_pharmacy_outlined,
          'supermercado' => Icons.shopping_cart_outlined,
          _ => Icons.cases_outlined,
        };

        final modules = _modulesForRole();

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) _confirmarSalida(context, onLogout);
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF2F5FA),
            bottomNavigationBar: Container(
              height: 38,
              color: brandColor,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '© BIOS Soluciones Informáticas — Todos los derechos reservados',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  Text(
                    _tenantLabel,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            appBar: AppBar(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logoB64 != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        base64Decode(logoB64),
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(_tenantLabel),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tenantIcon, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _tenantLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rol.toLowerCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmarSalida(context, onLogout),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                        ? 2
                        : 1;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Banner de bienvenida ──────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  brandColor,
                                  Color.lerp(brandColor, Colors.black, 0.2) ??
                                      brandColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.25),
                                  child: const Icon(Icons.person_outline,
                                      size: 28, color: Colors.white),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hola, ${_capitalizarNombre(nombreUsuario)}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_capitalizarNombre(rol)} · ${_capitalizarNombre(tenantNombre.isNotEmpty ? tenantNombre : "Mi Negocio")}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          // ── Módulos disponibles ───────────────────────────
                          Text(
                            'Módulos disponibles',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.6,
                            ),
                            itemCount: modules.length,
                            itemBuilder: (context, index) {
                              final module = modules[index];
                              return _StaffModuleCard(
                                module: module,
                                brandColor: brandColor,
                                onTap: module.isReady
                                    ? () => _openModule(context, module.title)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ), // Scaffold
        ); // PopScope
      },
    );
  }

  void _openModule(BuildContext context, String title) {
    switch (title) {
      case 'Productos':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ProductsManagementScreen(),
          ),
        );
        break;
      case 'Ventas / Caja':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VentasScreen()),
        );
        break;
      case 'Inventario':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventarioScreen()),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Módulo "$title" disponible próximamente'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de módulo para staff
// ─────────────────────────────────────────────────────────────────────────────

class _StaffModule {
  const _StaffModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isReady = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isReady;
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de módulo
// ─────────────────────────────────────────────────────────────────────────────

class _StaffModuleCard extends StatelessWidget {
  const _StaffModuleCard({
    required this.module,
    required this.brandColor,
    this.onTap,
  });

  final _StaffModule module;
  final Color brandColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isReady = module.isReady;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isReady ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isReady
                  ? brandColor.withOpacity(0.35)
                  : const Color(0xFFE6EAF0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isReady
                          ? brandColor.withOpacity(0.12)
                          : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      module.icon,
                      color: isReady ? brandColor : Colors.blueGrey.shade400,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  if (!isReady)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Próximo',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isReady
                          ? const Color(0xFF1A2438)
                          : Colors.blueGrey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
