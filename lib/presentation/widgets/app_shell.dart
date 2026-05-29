import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/screens/inventario/inventario_screen.dart';
import 'package:inventario_app/presentation/screens/products/products_management_screen.dart';
import 'package:inventario_app/presentation/screens/secciones/secciones_screen.dart';
import 'package:inventario_app/presentation/screens/proveedores/proveedores_screen.dart';
import 'package:inventario_app/presentation/screens/reportes/reportes_screen.dart';
import 'package:inventario_app/presentation/screens/users/users_management_screen.dart';
import 'package:inventario_app/presentation/screens/ventas/ventas_screen.dart';
import 'package:inventario_app/presentation/screens/salones/salones_screen.dart';

/// Shell principal de la app post-login.
/// Muestra sidebar izquierdo fijo + contenido dinámico.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _activeRoute = 'ventas'; // pantalla activa por defecto
  bool _sidebarExpanded = true; // colapsar/expandir sidebar

  Widget _buildContent(AuthProvider auth) {
    switch (_activeRoute) {
      case 'ventas':
        return const VentasScreen();
      case 'inventario':
        return const InventarioScreen();
      case 'productos':
        return const ProductsManagementScreen();
      case 'secciones':
        return const SeccionesScreen();
      case 'proveedores':
        return const ProveedoresScreen();
      case 'reportes':
        return const ReportesScreen();
      case 'usuarios':
        return const UsersManagementScreen();
      case 'salones':
        return const SalonesScreen();
      default:
        return const VentasScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isRestaurante =
        auth.tipoComercio == 'restaurante' || auth.tipoComercio == 'kiosko';
    final esAdmin = auth.rol.toLowerCase() == 'admin' ||
        auth.rol.toLowerCase() == 'superadmin';
    final esCajero = auth.rol.toLowerCase() == 'cajero';
    final esBodeguero = auth.rol.toLowerCase() == 'bodeguero';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: _sidebarExpanded ? 230 : 64,
            child: _Sidebar(
              expanded: _sidebarExpanded,
              activeRoute: _activeRoute,
              isAdmin: esAdmin,
              isCajero: esCajero,
              isBodeguero: esBodeguero,
              isRestaurante: isRestaurante,
              auth: auth,
              onNavigate: (route) => setState(() => _activeRoute = route),
              onToggle: () =>
                  setState(() => _sidebarExpanded = !_sidebarExpanded),
            ),
          ),
          // ── Contenido ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // TopBar
                _TopBar(auth: auth, expanded: _sidebarExpanded),
                // Contenido principal
                Expanded(
                  child: _buildContent(auth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.expanded,
    required this.activeRoute,
    required this.isAdmin,
    required this.isCajero,
    required this.isBodeguero,
    required this.isRestaurante,
    required this.auth,
    required this.onNavigate,
    required this.onToggle,
  });

  final bool expanded;
  final String activeRoute;
  final bool isAdmin, isCajero, isBodeguero, isRestaurante;
  final AuthProvider auth;
  final ValueChanged<String> onNavigate;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final brandColor = auth.marcaPrimaryColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2035),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo / brand
          _SidebarHeader(
              expanded: expanded,
              auth: auth,
              brandColor: brandColor,
              onToggle: onToggle),
          // Nav items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  if (isAdmin || isCajero) ...[
                    _SidebarLabel(label: 'VENTAS', expanded: expanded),
                    _NavItem(
                      icon: Icons.receipt_outlined,
                      label: 'Facturación',
                      route: 'ventas',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('ventas'),
                    ),
                  ],
                  if (isAdmin || isBodeguero) ...[
                    _SidebarLabel(label: 'INVENTARIO', expanded: expanded),
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Productos',
                      route: 'productos',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('productos'),
                    ),
                    _NavItem(
                      icon: Icons.category_outlined,
                      label: 'Secciones',
                      route: 'secciones',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('secciones'),
                    ),
                    _NavItem(
                      icon: Icons.local_shipping_outlined,
                      label: 'Proveedores',
                      route: 'proveedores',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('proveedores'),
                    ),
                    _NavItem(
                      icon: Icons.warehouse_outlined,
                      label: 'Inventario',
                      route: 'inventario',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('inventario'),
                    ),
                  ],
                  if (isAdmin) ...[
                    _SidebarLabel(label: 'ANÁLISIS', expanded: expanded),
                    _NavItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Reportes',
                      route: 'reportes',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('reportes'),
                    ),
                    _SidebarLabel(label: 'CONFIGURACIÓN', expanded: expanded),
                    _NavItem(
                      icon: Icons.people_alt_outlined,
                      label: 'Usuarios',
                      route: 'usuarios',
                      activeRoute: activeRoute,
                      expanded: expanded,
                      onTap: () => onNavigate('usuarios'),
                    ),
                    if (isRestaurante)
                      _NavItem(
                        icon: Icons.table_restaurant,
                        label: 'Salones',
                        route: 'salones',
                        activeRoute: activeRoute,
                        expanded: expanded,
                        onTap: () => onNavigate('salones'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Logout
          const Divider(color: Colors.white12, height: 1),
          _NavItem(
            icon: Icons.logout,
            label: 'Cerrar Sesión',
            route: '__logout__',
            activeRoute: '',
            expanded: expanded,
            onTap: auth.logout,
            danger: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.expanded,
    required this.auth,
    required this.brandColor,
    required this.onToggle,
  });
  final bool expanded;
  final AuthProvider auth;
  final Color brandColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final logo = auth.marcaLogoBase64;
    return Container(
      color: Colors.black12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          // Logo o icono
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: logo != null
                ? Image.memory(base64Decode(logo), fit: BoxFit.cover)
                : const Icon(Icons.storefront, color: Colors.white, size: 22),
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auth.tenantNombre.isNotEmpty ? auth.tenantNombre : 'Liris',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    auth.sucursalNombre.isNotEmpty
                        ? auth.sucursalNombre
                        : auth.tipoComercio,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          // Toggle button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                expanded ? Icons.chevron_left : Icons.chevron_right,
                color: Colors.white54,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.label, required this.expanded});
  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.activeRoute,
    required this.expanded,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label, route, activeRoute;
  final bool expanded, danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = activeRoute == route;
    return Tooltip(
      message: expanded ? '' : label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border(
                    left: BorderSide(
                        color: danger ? Colors.red : AppColors.accent,
                        width: 3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? (danger ? Colors.red : AppColors.accent)
                    : danger
                        ? Colors.red.shade300
                        : Colors.white60,
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : danger
                              ? Colors.red.shade300
                              : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TopBar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.auth, required this.expanded});
  final AuthProvider auth;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: const Color(0xFF171B21),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              auth.tenantNombre.isNotEmpty ? auth.tenantNombre : 'Liris',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          // Nombre usuario + rol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: Colors.white60),
                const SizedBox(width: 6),
                Text(
                  auth.nombreUsuario.isNotEmpty
                      ? auth.nombreUsuario
                      : auth.loginUsername,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    auth.rol,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
