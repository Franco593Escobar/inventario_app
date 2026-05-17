import 'package:flutter/material.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/presentation/screens/cliente_bios/cliente_bios_screen.dart';
import 'package:inventario_app/presentation/screens/dashboard/module_overview_screen.dart';
import 'package:inventario_app/presentation/screens/products/products_management_screen.dart';
import 'package:inventario_app/presentation/screens/users/users_management_screen.dart';

class SuperadminDashboardScreen extends StatelessWidget {
  const SuperadminDashboardScreen({
    super.key,
    required this.nombreUsuario,
    required this.tenantNombre,
    required this.sucursalNombre,
    required this.tipoComercio,
    required this.rol,
    required this.onLogout,
  });

  final String nombreUsuario;
  final String tenantNombre;
  final String sucursalNombre;
  final String tipoComercio;
  final String rol;
  final VoidCallback onLogout;

  /// Capitaliza la primera letra de cada palabra.
  static String _capitalizarNombre(String nombre) {
    return nombre
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get _tenantLabel {
    if (tenantNombre.trim().isNotEmpty) {
      return _capitalizarNombre(tenantNombre.trim());
    }
    return 'Grupo Ramones';
  }

  String get _sucursalLabel {
    if (sucursalNombre.trim().isNotEmpty) {
      return _capitalizarNombre(sucursalNombre.trim());
    }
    return 'Centro';
  }

  /// Icono del AppBar según tipo de comercio
  IconData get _tenantIcon => switch (tipoComercio) {
        'restaurante' => Icons.restaurant_outlined,
        'comercio' => Icons.store_outlined,
        _ => Icons.business_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final modules = [
      const _DashboardModule(
        title: 'Usuarios',
        subtitle: 'Gestiona accesos y permisos',
        icon: Icons.people_alt_outlined,
        isReady: true,
      ),
      const _DashboardModule(
        title: 'Productos',
        subtitle: 'Consulta y organiza el catalogo',
        icon: Icons.inventory_2_outlined,
        isReady: true,
      ),
      const _DashboardModule(
        title: 'Inventario',
        subtitle: 'Revisa stock y movimientos',
        icon: Icons.warehouse_outlined,
        isReady: true,
      ),
      const _DashboardModule(
        title: 'Ventas',
        subtitle: 'Visualiza operaciones recientes',
        icon: Icons.point_of_sale_outlined,
        isReady: true,
      ),
      const _DashboardModule(
        title: 'Cliente BIOS',
        subtitle: 'Configura el negocio activo del dashboard',
        icon: Icons.domain_outlined,
        isReady: true,
      ),
      const _DashboardModule(
        title: 'Reportes',
        subtitle: 'Accede a indicadores clave',
        icon: Icons.bar_chart_outlined,
      ),
      const _DashboardModule(
        title: 'Configuracion',
        subtitle: 'Ajusta parametros del sistema',
        icon: Icons.settings_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Centro de Mando'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFDDE3EF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tenantIcon, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _tenantLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rol.toLowerCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
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
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesion',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 1100
              ? 3
              : constraints.maxWidth >= 700
                  ? 2
                  : 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF12213D), Color(0xFF284A83)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 720,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dashboard Superadmin Multinegocio',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Bienvenido, ${_capitalizarNombre(nombreUsuario)}. Administra Negocios, Sucursales, Operación y Rentabilidad desde una Vista más Vendible para Web.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.86),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: const [
                                    _HeroChip(label: 'Multinegocio listo'),
                                    _HeroChip(label: 'Web + Android'),
                                    _HeroChip(label: 'POS + Reportes'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _ExecutiveMiniCard(
                                title: 'Rol activo',
                                value: rol,
                              ),
                              _ExecutiveMiniCard(
                                title: 'Sucursal',
                                value: _sucursalLabel,
                              ),
                              const _ExecutiveMiniCard(
                                title: 'Canal',
                                value: 'Web + Android',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: const [
                        _ExecutiveMetricCard(
                          title: 'Ventas del día',
                          value: '\$3.240',
                          detail: 'Meta diaria al 78%',
                        ),
                        _ExecutiveMetricCard(
                          title: 'Utilidad estimada',
                          value: '\$980',
                          detail: 'Margen controlado por negocio',
                        ),
                        _ExecutiveMetricCard(
                          title: 'Negocios activos',
                          value: '4',
                          detail: '1 tenant con varias sucursales',
                        ),
                        _ExecutiveMetricCard(
                          title: 'Alertas críticas',
                          value: '6',
                          detail: 'Stock, caja y metas',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Módulos de Operación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 190,
                      ),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        return _DashboardCard(module: module);
                      },
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: const [
                        _InsightPanel(
                          title: 'Valor Comercial',
                          items: [
                            'Operación centralizada para varios negocios',
                            'Base para kiosko, cocina y delivery',
                            'Dashboard ejecutivo apto para demo comercial',
                          ],
                        ),
                        _InsightPanel(
                          title: 'Prioridades Sugeridas',
                          items: [
                            'Tenants y sucursales reales',
                            'Arqueo y caja por turno',
                            'Restaurante: mesas, KDS y pagos mixtos',
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.module});

  final _DashboardModule module;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (module.title == 'Usuarios') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UsersManagementScreen(),
              ),
            );
            return;
          }

          if (module.title == 'Productos') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductsManagementScreen(),
              ),
            );
            return;
          }

          if (module.title == 'Cliente BIOS') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ClienteBiosScreen(),
              ),
            );
            return;
          }

          if (module.isReady) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ModuleOverviewScreen(
                  title: module.title,
                  description: _moduleDescription(module.title),
                  icon: module.icon,
                  items: _moduleItems(module.title),
                ),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${module.title}: modulo en construccion')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        Icon(module.icon, color: AppColors.primary, size: 28),
                  ),
                  _ModuleBadge(isReady: module.isReady),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                module.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                module.subtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.blueGrey.shade700,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    module.isReady ? 'Abrir módulo' : 'Pendiente',
                    style: TextStyle(
                      color: module.isReady
                          ? AppColors.primary
                          : Colors.blueGrey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  const _ModuleBadge({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppColors.success : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isReady ? 'Listo' : 'Base',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _ExecutiveMiniCard extends StatelessWidget {
  const _ExecutiveMiniCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveMetricCard extends StatelessWidget {
  const _ExecutiveMetricCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 324,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.blueGrey.shade700)),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: TextStyle(color: Colors.blueGrey.shade600)),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 684,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardModule {
  const _DashboardModule({
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

String _moduleDescription(String title) {
  switch (title) {
    case 'Usuarios':
      return 'Base inicial para administrar usuarios, revisar permisos y preparar el mantenimiento de accesos.';
    case 'Productos':
      return 'Base inicial para organizar el catalogo, controlar informacion general y preparar futuras operaciones.';
    case 'Inventario':
      return 'Base inicial para revisar existencias, movimientos y trazabilidad del stock.';
    case 'Ventas':
      return 'Base inicial para consultar operaciones, preparar registros y seguimiento comercial.';
    default:
      return 'Modulo base del sistema.';
  }
}

List<String> _moduleItems(String title) {
  switch (title) {
    case 'Usuarios':
      return const [
        'Ver listado general de usuarios',
        'Preparar alta y edicion de accesos',
        'Definir perfiles y permisos por rol',
      ];
    case 'Productos':
      return const [
        'Visualizar catalogo de productos',
        'Preparar registro de nuevos productos',
        'Organizar categorias y datos comerciales',
      ];
    case 'Inventario':
      return const [
        'Consultar stock actual por item',
        'Preparar movimientos de entrada y salida',
        'Revisar alertas de existencia minima',
      ];
    case 'Ventas':
      return const [
        'Consultar resumen de ventas',
        'Preparar historial de operaciones',
        'Definir flujo de registro comercial',
      ];
    default:
      return const ['Modulo base del sistema'];
  }
}
