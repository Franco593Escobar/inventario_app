import 'package:flutter/material.dart';
import 'package:inventario_app/core/constants/app_colors.dart';

class SuperadminDashboardScreen extends StatelessWidget {
  const SuperadminDashboardScreen({
    super.key,
    required this.nombreUsuario,
    required this.rol,
    required this.onLogout,
  });

  final String nombreUsuario;
  final String rol;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final modules = [
      const _DashboardModule(
        title: 'Usuarios',
        subtitle: 'Gestiona accesos y permisos',
        icon: Icons.people_alt_outlined,
      ),
      const _DashboardModule(
        title: 'Productos',
        subtitle: 'Consulta y organiza el catalogo',
        icon: Icons.inventory_2_outlined,
      ),
      const _DashboardModule(
        title: 'Inventario',
        subtitle: 'Revisa stock y movimientos',
        icon: Icons.warehouse_outlined,
      ),
      const _DashboardModule(
        title: 'Ventas',
        subtitle: 'Visualiza operaciones recientes',
        icon: Icons.point_of_sale_outlined,
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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Panel superadmin'),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Wrap(
                    runSpacing: 16,
                    spacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenido, $nombreUsuario',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rol activo: $rol',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Desde aqui puedes administrar las areas principales del sistema.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 52,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Accesos principales',
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
                    mainAxisExtent: 170,
                  ),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    return _DashboardCard(module: module);
                  },
                ),
              ],
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${module.title}: modulo en construccion')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: AppColors.primary, size: 28),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardModule {
  const _DashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
