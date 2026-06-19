import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/app_user.dart';
import 'package:inventario_app/data/models/usuario_bios.dart';
import 'package:inventario_app/data/repositories/user_repository.dart';
import 'package:inventario_app/data/repositories/usuario_bios_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class UsuarioBiosScreen extends StatefulWidget {
  const UsuarioBiosScreen({super.key});

  @override
  State<UsuarioBiosScreen> createState() => _UsuarioBiosScreenState();
}

class _UsuarioBiosScreenState extends State<UsuarioBiosScreen> {
  final _repository = UsuarioBiosRepository();
  final _userRepository = UserRepository();
  final _searchController = TextEditingController();
  List<UsuarioBios> _cachedUsuarios = [];
  late final Stream<List<UsuarioBios>> _usuariosStream;

  @override
  void initState() {
    super.initState();
    _usuariosStream = _repository.watchAll();
  }

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

  List<UsuarioBios> _filterUsuarios(List<UsuarioBios> all) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((u) {
      return u.nombreNegocio.toLowerCase().contains(q) ||
          u.identificador.toLowerCase().contains(q) ||
          u.cedula.toLowerCase().contains(q) ||
          u.nombres.toLowerCase().contains(q) ||
          u.apellidos.toLowerCase().contains(q) ||
          u.tipoComercio.toLowerCase().contains(q) ||
          u.dueno.toLowerCase().contains(q) ||
          (u.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Seleccionar como activo ───────────────────────────────

  Future<void> _seleccionarActivo(UsuarioBios usuario) async {
    if (usuario.activo) return;
    await _repository.setActivo(usuario.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '"${usuario.nombreNegocio}" es ahora el negocio activo del dashboard.'),
      backgroundColor: AppColors.success,
    ));
  }

  // ── Dialogo Crear / Editar ────────────────────────────────

  Future<void> _openForm([UsuarioBios? usuario]) async {
    final auditor = context.mounted
        ? Provider.of<AuthProvider>(context, listen: false).nombreUsuario
        : 'BIOS';

    final identificadorCtrl =
        TextEditingController(text: usuario?.identificador ?? '');
    final cedulaCtrl = TextEditingController(text: usuario?.cedula ?? '');
    final nombreNegocioCtrl =
        TextEditingController(text: usuario?.nombreNegocio ?? '');
    final duenoCtrl = TextEditingController(text: usuario?.dueno ?? '');
    final nombresCtrl = TextEditingController(text: usuario?.nombres ?? '');
    final apellidosCtrl = TextEditingController(text: usuario?.apellidos ?? '');
    final nombreUsuarioCtrl =
        TextEditingController(text: usuario?.nombreUsuario ?? '');
    final passwordCtrl = TextEditingController(text: usuario?.password ?? '');
    final emailCtrl = TextEditingController(text: usuario?.email ?? '');
    final telefonoCtrl = TextEditingController(text: usuario?.telefono ?? '');
    final celularCtrl = TextEditingController(text: usuario?.celular ?? '');
    final direccionCtrl = TextEditingController(text: usuario?.direccion ?? '');

    final formKey = GlobalKey<FormState>();
    final DateTime fechaCreacion = usuario?.fechaCreacion ?? DateTime.now();
    String selectedTipo =
        usuario?.tipoComercio ?? UsuarioBios.tiposComercio.first;
    String selectedPago =
        usuario?.pagoServicio ?? UsuarioBios.pagoServicios.first;
    String? warnId;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          void checkDupId(String v) {
            final exists = _cachedUsuarios.any((u) =>
                u.identificador.toLowerCase() == v.trim().toLowerCase() &&
                u.id != (usuario?.id ?? ''));
            setDialogState(() =>
                warnId = exists ? 'El identificador "$v" ya existe.' : null);
          }

          Future<void> guardar() async {
            if (!formKey.currentState!.validate()) return;

            final draft = UsuarioBios(
              id: usuario?.id ?? '',
              identificador: identificadorCtrl.text.trim(),
              cedula: cedulaCtrl.text.trim(),
              nombreNegocio: nombreNegocioCtrl.text.trim(),
              tipoComercio: selectedTipo,
              dueno: duenoCtrl.text.trim(),
              pagoServicio: selectedPago,
              nombres: nombresCtrl.text.trim(),
              apellidos: apellidosCtrl.text.trim(),
              nombreUsuario: nombreUsuarioCtrl.text.trim(),
              password: passwordCtrl.text.trim(),
              rol: 'admin',
              estadoActivo: true,
              activo: usuario?.activo ?? false,
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
              creadoPor: usuario?.creadoPor ?? auditor,
              modificadoPor: auditor,
            );

            // Guardar en usuario_bios y obtener el id del documento
            await _repository.save(draft);

            // Si es registro nuevo, crear también el admin en la colección usuarios
            if (usuario == null) {
              final adminUser = AppUser(
                id: '',
                identificador: draft.identificador,
                cedula: draft.cedula,
                nombreUsuario: draft.nombreUsuario,
                nombres: draft.nombres,
                apellidos: draft.apellidos,
                password: draft.password,
                rol: 'admin',
                estadoActivo: true,
                fechaCreacion: fechaCreacion,
                email: draft.email,
                telefono: draft.telefono,
                celular: draft.celular,
                direccion: draft.direccion,
                creadoPor: auditor,
                modificadoPor: auditor,
              );
              await _userRepository.createUser(adminUser);
            }

            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
          }

          return AdminFormDialog(
            title: usuario == null ? 'Nuevo Negocio BIOS' : 'Editar Negocio',
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
                    _buildField(
                      controller: duenoCtrl,
                      label: 'DUEÑO DEL NEGOCIO *',
                      hint: 'ej. Fabian Ramon',
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
                        items: UsuarioBios.tiposComercio.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(UsuarioBios.tipoLabel[t] ?? t),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedTipo = v);
                          }
                        },
                      ),
                    ),
                    // Plan de pago
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        value: selectedPago,
                        decoration: const InputDecoration(
                          labelText: 'PLAN DE PAGO *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: UsuarioBios.pagoServicios.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(UsuarioBios.pagoLabel[p] ?? p),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedPago = v);
                          }
                        },
                      ),
                    ),
                    _buildField(
                      controller: identificadorCtrl,
                      label: 'IDENTIFICADOR *',
                      hint: 'ej. N01',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!RegExp(r'^[A-Za-z]\d+$').hasMatch(v.trim())) {
                          return 'Formato: letra + número, ej. N01';
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
                    if (usuario == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade700, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Al crear el negocio, se genera automáticamente el usuario admin con estas credenciales.',
                                style: TextStyle(
                                    color: Colors.blue.shade800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildField(
                      controller: nombreUsuarioCtrl,
                      label: 'USUARIO ADMIN *',
                      hint: 'ej. 593br-bframon',
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
                child: Text(usuario == null ? 'Guardar' : 'Actualizar'),
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
      duenoCtrl.dispose();
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
        content: Text(usuario == null
            ? 'Negocio registrado y usuario admin creado.'
            : 'Negocio actualizado correctamente.'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  // ── Eliminar ──────────────────────────────────────────────

  Future<void> _deleteUsuario(UsuarioBios usuario) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar negocio'),
        content: Text(
            '¿Eliminar "${usuario.nombreNegocio}"? Esta acción no se puede deshacer.'),
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
      await _repository.delete(usuario.id);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UsuarioBios>>(
      stream: _usuariosStream,
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

        final usuarios = snapshot.data!;
        if (usuarios != _cachedUsuarios) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _cachedUsuarios = usuarios);
          });
        }
        final filtered = _filterUsuarios(usuarios);
        final activos = usuarios.where((u) => u.activo).length;
        final total = usuarios.length;

        return AdminModuleShell(
          title: 'Negocios BIOS',
          subtitle:
              'Gestiona los negocios que contratan el servicio. Elige el negocio activo para que aparezca en el dashboard.',
          metricChips: [
            AdminMetricChip(label: 'Total', value: total.toString()),
            AdminMetricChip(
                label: 'Activo en dashboard',
                value: activos > 0 ? 'Sí' : 'Ninguno'),
          ],
          primaryAction: AdminPrimaryButton(
            label: 'Nuevo Negocio',
            icon: Icons.add,
            onPressed: () => _openForm(),
          ),
          filters: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, dueño, tipo, cédula…',
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
                      'No se encontraron negocios.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _UsuarioRowCard(
                    usuario: filtered[i],
                    onEdit: () => _openForm(filtered[i]),
                    onDelete: () => _deleteUsuario(filtered[i]),
                    onSeleccionar: () => _seleccionarActivo(filtered[i]),
                    capitalizarNombre: _capitalizarNombre,
                  ),
                ),
        );
      },
    );
  }
}

// ── Helpers de formulario ────────────────────────────────────

Widget _buildSection(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF2563EB),
            letterSpacing: 0.4,
          ),
        ),
      ),
      ...children,
      const SizedBox(height: 8),
    ],
  );
}

Widget _buildField({
  required TextEditingController controller,
  required String label,
  String? hint,
  bool obscureText = false,
  int maxLines = 1,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
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

// ─────────────────────────────────────────────────────────────
// Row card de cada negocio
// ─────────────────────────────────────────────────────────────

class _UsuarioRowCard extends StatelessWidget {
  const _UsuarioRowCard({
    required this.usuario,
    required this.onEdit,
    required this.onDelete,
    required this.onSeleccionar,
    required this.capitalizarNombre,
  });

  final UsuarioBios usuario;
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
    final activo = usuario.activo;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: activo ? AppColors.success : Colors.grey.shade200,
          width: activo ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icono por tipo
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: activo
                  ? AppColors.success.withOpacity(0.1)
                  : Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForTipo(usuario.tipoComercio),
              color: activo ? AppColors.success : Colors.blueGrey,
              size: 22,
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
                      capitalizarNombre(usuario.nombreNegocio),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (activo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ACTIVO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Dueño: ${capitalizarNombre(usuario.dueno)}  ·  '
                  '${UsuarioBios.tipoLabel[usuario.tipoComercio] ?? usuario.tipoComercio}  ·  '
                  'Pago: ${UsuarioBios.pagoLabel[usuario.pagoServicio] ?? usuario.pagoServicio}',
                  style:
                      TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                ),
                Text(
                  'Admin: ${usuario.nombreUsuario}  ·  ID: ${usuario.identificador}',
                  style:
                      TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),

          // Acciones
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Activar / Activo
              if (!activo)
                OutlinedButton.icon(
                  onPressed: onSeleccionar,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Activar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: BorderSide(color: AppColors.success),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Activo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: BorderSide(color: AppColors.success.withOpacity(0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar',
                color: Colors.blueGrey,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
