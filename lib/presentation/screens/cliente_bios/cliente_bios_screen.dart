import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/cliente_bios.dart';
import 'package:inventario_app/data/repositories/cliente_bios_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class ClienteBiosScreen extends StatefulWidget {
  const ClienteBiosScreen({super.key});

  @override
  State<ClienteBiosScreen> createState() => _ClienteBiosScreenState();
}

class _ClienteBiosScreenState extends State<ClienteBiosScreen> {
  final _repository = ClienteBiosRepository();
  final _searchController = TextEditingController();
  List<ClienteBios> _cachedClientes = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────

  static String _capitalizarNombre(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  List<ClienteBios> _filterClientes(List<ClienteBios> all) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) {
      return c.nombreNegocio.toLowerCase().contains(q) ||
          c.identificador.toLowerCase().contains(q) ||
          c.cedula.toLowerCase().contains(q) ||
          c.nombres.toLowerCase().contains(q) ||
          c.apellidos.toLowerCase().contains(q) ||
          c.tipoComercio.toLowerCase().contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Seleccionar como activo ───────────────────────────────

  Future<void> _seleccionarActivo(ClienteBios cliente) async {
    if (cliente.activo) return; // ya es el activo
    await _repository.setActivo(cliente.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '"${cliente.nombreNegocio}" es ahora el cliente activo del dashboard.'),
      backgroundColor: AppColors.success,
    ));
  }

  // ── Dialogo Crear / Editar ────────────────────────────────

  Future<void> _openForm([ClienteBios? cliente]) async {
    final auditor =
        Provider.of<AuthProvider>(context, listen: false).nombreUsuario;

    final identificadorCtrl =
        TextEditingController(text: cliente?.identificador ?? '');
    final cedulaCtrl = TextEditingController(text: cliente?.cedula ?? '');
    final nombreNegocioCtrl =
        TextEditingController(text: cliente?.nombreNegocio ?? '');
    final nombresCtrl = TextEditingController(text: cliente?.nombres ?? '');
    final apellidosCtrl = TextEditingController(text: cliente?.apellidos ?? '');
    final nombreUsuarioCtrl =
        TextEditingController(text: cliente?.nombreUsuario ?? '');
    final passwordCtrl = TextEditingController(text: cliente?.password ?? '');
    final emailCtrl = TextEditingController(text: cliente?.email ?? '');
    final telefonoCtrl = TextEditingController(text: cliente?.telefono ?? '');
    final celularCtrl = TextEditingController(text: cliente?.celular ?? '');
    final direccionCtrl = TextEditingController(text: cliente?.direccion ?? '');

    final formKey = GlobalKey<FormState>();
    final DateTime fechaCreacion = cliente?.fechaCreacion ?? DateTime.now();
    String selectedTipo =
        cliente?.tipoComercio ?? ClienteBios.tiposComercio.first;
    String? warnId;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          void checkDupId(String v) {
            final exists = _cachedClientes.any((c) =>
                c.identificador.toLowerCase() == v.trim().toLowerCase() &&
                c.id != (cliente?.id ?? ''));
            setDialogState(() =>
                warnId = exists ? 'El identificador "$v" ya existe.' : null);
          }

          Future<void> guardar() async {
            if (!formKey.currentState!.validate()) return;
            final draft = ClienteBios(
              id: cliente?.id ?? '',
              identificador: identificadorCtrl.text.trim(),
              cedula: cedulaCtrl.text.trim(),
              nombreNegocio: nombreNegocioCtrl.text.trim(),
              tipoComercio: selectedTipo,
              nombres: nombresCtrl.text.trim(),
              apellidos: apellidosCtrl.text.trim(),
              nombreUsuario: nombreUsuarioCtrl.text.trim(),
              password: passwordCtrl.text.trim(),
              rol: 'cliente',
              estadoActivo: true,
              activo: cliente?.activo ?? false,
              fechaCreacion: fechaCreacion,
              email:
                  emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              telefono: telefonoCtrl.text.trim().isEmpty
                  ? null
                  : telefonoCtrl.text.trim(),
              celular: celularCtrl.text.trim().isEmpty
                  ? null
                  : celularCtrl.text.trim(),
              direccion: direccionCtrl.text.trim().isEmpty
                  ? null
                  : direccionCtrl.text.trim(),
              creadoPor: cliente?.creadoPor ?? auditor,
              modificadoPor: auditor,
            );
            await _repository.save(draft);
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
          }

          return AdminFormDialog(
            title: cliente == null ? 'Nuevo Cliente BIOS' : 'Editar Cliente',
            body: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Advertencia duplicado
                  if (warnId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.amber.shade800, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(warnId!,
                                style: TextStyle(color: Colors.amber.shade900)),
                          ),
                        ],
                      ),
                    ),

                  _buildSection('Datos del Negocio', [
                    _buildField(
                      controller: nombreNegocioCtrl,
                      label: 'NOMBRE DEL NEGOCIO *',
                      hint: 'ej. Grupo Ramones',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    // Tipo de comercio
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        value: selectedTipo,
                        decoration: const InputDecoration(
                          labelText: 'TIPO DE COMERCIO *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: ClienteBios.tiposComercio.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(ClienteBios.tipoLabel[t] ?? t),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedTipo = v);
                          }
                        },
                      ),
                    ),
                    _buildField(
                      controller: identificadorCtrl,
                      label: 'IDENTIFICADOR *',
                      hint: 'ej. C01',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Requerido';
                        }
                        if (!RegExp(r'^[A-Za-z]\d+$').hasMatch(v.trim())) {
                          return 'Formato: letra + número, ej. C01';
                        }
                        return null;
                      },
                      onChanged: checkDupId,
                    ),
                    _buildField(
                      controller: cedulaCtrl,
                      label: 'CÉDULA / RUC *',
                      hint: 'ej. 1234567890',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ]),

                  _buildSection('Contacto', [
                    _buildField(
                      controller: nombresCtrl,
                      label: 'NOMBRES *',
                      hint: 'Nombre del representante',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    _buildField(
                      controller: apellidosCtrl,
                      label: 'APELLIDOS *',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    _buildField(
                      controller: emailCtrl,
                      label: 'CORREO',
                      hint: 'correo@dominio.com',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$')
                                .hasMatch(v.trim())
                            ? null
                            : 'Correo inválido';
                      },
                    ),
                    _buildField(
                        controller: telefonoCtrl,
                        label: 'TELÉFONO',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return RegExp(r'^\d{7,15}$').hasMatch(v.trim())
                              ? null
                              : 'Solo dígitos, 7–15 caracteres';
                        }),
                    _buildField(
                        controller: celularCtrl,
                        label: 'CELULAR',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return RegExp(r'^\d{7,15}$').hasMatch(v.trim())
                              ? null
                              : 'Solo dígitos, 7–15 caracteres';
                        }),
                    _buildField(
                      controller: direccionCtrl,
                      label: 'DIRECCIÓN',
                      maxLines: 2,
                    ),
                  ]),

                  _buildSection('Acceso al sistema', [
                    _buildField(
                      controller: nombreUsuarioCtrl,
                      label: 'USUARIO *',
                      hint: 'nombre de acceso',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    _buildField(
                      controller: passwordCtrl,
                      label: 'CONTRASEÑA *',
                      obscureText: true,
                      validator: (v) => (v != null && v.length >= 6)
                          ? null
                          : 'Mínimo 6 caracteres',
                    ),
                  ]),

                  // Fecha de creación (solo lectura)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'FECHA DE CREACIÓN',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                      ),
                      child: Text(
                        '${fechaCreacion.day.toString().padLeft(2, '0')}/'
                        '${fechaCreacion.month.toString().padLeft(2, '0')}/'
                        '${fechaCreacion.year}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: guardar,
                child: Text(cliente == null ? 'Guardar' : 'Actualizar'),
              ),
            ],
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      identificadorCtrl.dispose();
      cedulaCtrl.dispose();
      nombreNegocioCtrl.dispose();
      nombresCtrl.dispose();
      apellidosCtrl.dispose();
      nombreUsuarioCtrl.dispose();
      passwordCtrl.dispose();
      emailCtrl.dispose();
      telefonoCtrl.dispose();
      celularCtrl.dispose();
      direccionCtrl.dispose();
    });

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cliente == null
            ? 'Cliente registrado correctamente.'
            : 'Cliente actualizado correctamente.'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  // ── Eliminar ──────────────────────────────────────────────

  Future<void> _deleteCliente(ClienteBios cliente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
            '¿Eliminar "${cliente.nombreNegocio}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.delete(cliente.id);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClienteBios>>(
      stream: _repository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final clientes = snapshot.data!;
        if (clientes != _cachedClientes) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _cachedClientes = clientes);
          });
        }
        final filtered = _filterClientes(clientes);
        final activos = clientes.where((c) => c.activo).length;
        final total = clientes.length;

        return AdminModuleShell(
          title: 'Clientes BIOS',
          subtitle:
              'Gestiona los negocios que contratan el servicio. Elige el cliente activo para que aparezca en el dashboard.',
          metricChips: [
            AdminMetricChip(label: 'Total', value: total.toString()),
            AdminMetricChip(
                label: 'Activo en dashboard',
                value: activos > 0 ? 'Sí' : 'Ninguno'),
          ],
          primaryAction: AdminPrimaryButton(
            label: 'Nuevo Cliente',
            icon: Icons.add,
            onPressed: () => _openForm(),
          ),
          filters: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, tipo, cédula…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          content: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No se encontraron clientes.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ClienteRowCard(
                    cliente: filtered[i],
                    onEdit: () => _openForm(filtered[i]),
                    onDelete: () => _deleteCliente(filtered[i]),
                    onSeleccionar: () => _seleccionarActivo(filtered[i]),
                    capitalizarNombre: _capitalizarNombre,
                  ),
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Row card de cada cliente
// ─────────────────────────────────────────────────────────────

class _ClienteRowCard extends StatelessWidget {
  const _ClienteRowCard({
    required this.cliente,
    required this.onEdit,
    required this.onDelete,
    required this.onSeleccionar,
    required this.capitalizarNombre,
  });

  final ClienteBios cliente;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSeleccionar;
  final String Function(String) capitalizarNombre;

  static IconData _iconForTipo(String tipo) => switch (tipo) {
        'restaurante' => Icons.restaurant_outlined,
        'comercio' => Icons.store_outlined,
        _ => Icons.business_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final activo = cliente.activo;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo
              ? AppColors.success.withOpacity(0.6)
              : const Color(0xFFE8EDF5),
          width: activo ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icono tipo
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: activo
                    ? AppColors.success.withOpacity(0.1)
                    : const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForTipo(cliente.tipoComercio),
                color: activo ? AppColors.success : AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // Info principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        capitalizarNombre(cliente.nombreNegocio),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TipoBadge(tipo: cliente.tipoComercio),
                      if (activo) ...[
                        const SizedBox(width: 8),
                        const _ActiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${capitalizarNombre(cliente.nombres)} ${capitalizarNombre(cliente.apellidos)}  •  Cédula: ${cliente.cedula}',
                    style: TextStyle(
                        color: Colors.blueGrey.shade600, fontSize: 13),
                  ),
                  if (cliente.email != null && cliente.email!.isNotEmpty)
                    Text(
                      cliente.email!,
                      style: TextStyle(
                          color: Colors.blueGrey.shade400, fontSize: 12),
                    ),
                ],
              ),
            ),

            // Acciones
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Botón "Seleccionar como activo"
                if (!activo)
                  Tooltip(
                    message: 'Seleccionar como cliente activo',
                    child: OutlinedButton.icon(
                      onPressed: onSeleccionar,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Activar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(
                            color: AppColors.success.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                else
                  Tooltip(
                    message: 'Este cliente está activo en el dashboard',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 4),
                          Text('Activo',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.primary,
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Chips auxiliares
// ─────────────────────────────────────────────────────────────

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({required this.tipo});
  final String tipo;

  static Color _color(String tipo) => switch (tipo) {
        'restaurante' => const Color(0xFFF97316),
        'comercio' => const Color(0xFF2563EB),
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(tipo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        ClienteBios.tipoLabel[tipo] ?? tipo,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'En dashboard',
        style: TextStyle(
            color: AppColors.success,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers de construcción del formulario
// ─────────────────────────────────────────────────────────────

Widget _buildSection(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ),
      ...children,
      const Divider(height: 28),
    ],
  );
}

Widget _buildField({
  required TextEditingController controller,
  required String label,
  String? hint,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
  bool obscureText = false,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}
