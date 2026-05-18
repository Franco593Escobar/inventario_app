import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/app_user.dart';
import 'package:inventario_app/data/repositories/user_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final UserRepository _repository = UserRepository();
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'todos';
  List<AppUser> _cachedUsers = [];

  String _formatDate(DateTime? value) {
    if (value == null) return 'Sin fecha';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatFirestoreError(Object error, String action) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No se pudo $action porque Firestore negó la escritura. Revisa las reglas de la colección usuarios.';
        case 'unavailable':
          return 'No se pudo $action porque el servicio no está disponible en este momento.';
        default:
          return 'No se pudo $action: ${error.message ?? error.code}';
      }
    }

    return 'No se pudo $action. Detalle: $error';
  }

  void _showFeedback(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  List<AppUser> _filterUsers(List<AppUser> users) {
    final query = _searchController.text.trim().toLowerCase();

    return users.where((user) {
      final matchesRole =
          _selectedRole == 'todos' || user.rol.toLowerCase() == _selectedRole;
      final matchesQuery = query.isEmpty ||
          user.identificador.toLowerCase().contains(query) ||
          user.cedula.toLowerCase().contains(query) ||
          user.nombreUsuario.toLowerCase().contains(query) ||
          user.nombres.toLowerCase().contains(query) ||
          user.apellidos.toLowerCase().contains(query) ||
          (user.email ?? '').toLowerCase().contains(query) ||
          (user.celular ?? '').toLowerCase().contains(query) ||
          user.rol.toLowerCase().contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  Future<void> _openUserForm([AppUser? user]) async {
    final identificadorController =
        TextEditingController(text: user?.identificador ?? '');
    final cedulaController = TextEditingController(text: user?.cedula ?? '');
    final nombreUsuarioController =
        TextEditingController(text: user?.nombreUsuario ?? '');
    final nombresController = TextEditingController(text: user?.nombres ?? '');
    final apellidosController =
        TextEditingController(text: user?.apellidos ?? '');
    final passwordController =
        TextEditingController(text: user?.password ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final telefonoController =
        TextEditingController(text: user?.telefono ?? '');
    final celularController = TextEditingController(text: user?.celular ?? '');
    final direccionController =
        TextEditingController(text: user?.direccion ?? '');
    // Fecha es automática al crear; en edición se conserva la original
    final DateTime fechaCreacion = user?.fechaCreacion ?? DateTime.now();
    String rol = user?.rol ?? 'vendedor';
    bool estadoActivo = user?.estadoActivo ?? true;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? submitError;
    // Advertencias de duplicado (no bloquean el guardado)
    String? warnCedula;
    String? warnId;
    // Auditoría: usuario actualmente logueado
    final auditor =
        Provider.of<AuthProvider>(context, listen: false).nombreUsuario;
    final authTenantId =
        Provider.of<AuthProvider>(context, listen: false).tenantId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isWide = MediaQuery.of(context).size.width > 900;

            return AdminFormDialog(
              title: user == null ? 'Nuevo Usuario' : 'Editar Usuario',
              body: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: identificadorController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'IDENTIFICADOR *',
                              hintText: 'Ej. B01, B02…',
                            ),
                            onChanged: (v) {
                              final dup = _cachedUsers.any((u) =>
                                  u.id != (user?.id ?? '') &&
                                  u.identificador.trim().toUpperCase() ==
                                      v.trim().toUpperCase());
                              setDialogState(() => warnId = dup
                                  ? 'El identificador "${v.trim()}" ya pertenece a otro usuario'
                                  : null);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa el identificador';
                              }
                              if (!RegExp(r'^[A-Za-z]\d+$')
                                  .hasMatch(value.trim())) {
                                return 'Formato: letra + números (B01, B02…)';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: cedulaController,
                            decoration: const InputDecoration(
                              labelText: 'CEDULA *',
                              hintText: 'Documento de identidad',
                            ),
                            onChanged: (v) {
                              final dup = _cachedUsers.any((u) =>
                                  u.id != (user?.id ?? '') &&
                                  u.cedula.trim() == v.trim());
                              setDialogState(() => warnCedula = dup
                                  ? 'La cédula "${v.trim()}" ya está registrada en otro usuario'
                                  : null);
                            },
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Ingresa la cédula'
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: nombreUsuarioController,
                            decoration: const InputDecoration(
                              labelText: 'USUARIO *',
                              hintText: 'Nombre de usuario',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Ingresa el usuario'
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: nombresController,
                            decoration: const InputDecoration(
                              labelText: 'NOMBRE *',
                              hintText: 'Nombre completo',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Ingresa el nombre'
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: apellidosController,
                            decoration: const InputDecoration(
                              labelText: 'APELLIDOS *',
                              hintText: 'Apellidos del usuario',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Ingresa los apellidos'
                                    : null,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: DropdownButtonFormField<String>(
                            value: rol,
                            decoration: const InputDecoration(
                              labelText: 'ROL *',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'superadmin',
                                child: Text('superadmin'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('admin'),
                              ),
                              DropdownMenuItem(
                                value: 'vendedor',
                                child: Text('vendedor'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() => rol = value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'CONTRASEÑA *',
                              hintText: 'Mínimo 6 caracteres',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa la contraseña';
                              }
                              if (value.trim().length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'TELEFONO',
                              hintText: 'Solo dígitos',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              if (!RegExp(r'^\d{7,15}$')
                                  .hasMatch(value.trim())) {
                                return 'Solo dígitos, 7 a 15 caracteres';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: celularController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'CELULAR',
                              hintText: 'Solo dígitos',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              if (!RegExp(r'^\d{7,15}$')
                                  .hasMatch(value.trim())) {
                                return 'Solo dígitos, 7 a 15 caracteres';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'CORREO',
                              hintText: 'correo@dominio.com',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$')
                                  .hasMatch(value.trim())) {
                                return 'Correo no válido';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: isWide ? double.infinity : double.infinity,
                          child: TextFormField(
                            controller: direccionController,
                            decoration: const InputDecoration(
                              labelText: 'DIRECCION',
                              hintText: 'Direccion del usuario',
                            ),
                            maxLines: 2,
                            minLines: 1,
                          ),
                        ),
                        // FECHA DE CREACION: automatica, solo lectura
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'FECHA DE CREACION',
                              border: const OutlineInputBorder(),
                              suffixIcon: Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                            child: Text(
                              _formatDate(fechaCreacion),
                              style: TextStyle(
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Advertencias de duplicado (no bloquean guardar)
                    if (warnCedula != null || warnId != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (warnCedula != null) _WarnRow(text: warnCedula!),
                            if (warnId != null) ...[
                              if (warnCedula != null) const SizedBox(height: 4),
                              _WarnRow(text: warnId!),
                            ],
                          ],
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usuario activo'),
                      value: estadoActivo,
                      onChanged: (value) {
                        setDialogState(() => estadoActivo = value);
                      },
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          submitError!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setDialogState(() {
                      isSubmitting = true;
                      submitError = null;
                    });

                    final draft = AppUser(
                      id: user?.id ?? '',
                      identificador: identificadorController.text.trim(),
                      cedula: cedulaController.text.trim(),
                      nombreUsuario: nombreUsuarioController.text.trim(),
                      nombres: nombresController.text.trim(),
                      apellidos: apellidosController.text.trim(),
                      password: passwordController.text.trim(),
                      rol: rol,
                      estadoActivo: estadoActivo,
                      tenantId: user?.tenantId ?? authTenantId,
                      fechaCreacion: fechaCreacion,
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                      telefono: telefonoController.text.trim().isEmpty
                          ? null
                          : telefonoController.text.trim(),
                      celular: celularController.text.trim().isEmpty
                          ? null
                          : celularController.text.trim(),
                      direccion: direccionController.text.trim().isEmpty
                          ? null
                          : direccionController.text.trim(),
                      // Auditoría: preservar creadoPor en edición
                      creadoPor: user?.creadoPor ?? auditor,
                      modificadoPor: auditor,
                    );

                    try {
                      if (user == null) {
                        await _repository.createUser(draft);
                      } else {
                        await _repository.updateUser(draft);
                      }
                    } catch (error) {
                      setDialogState(() {
                        isSubmitting = false;
                        submitError = _formatFirestoreError(
                          error,
                          user == null
                              ? 'crear el usuario'
                              : 'actualizar el usuario',
                        );
                      });
                      return;
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );

    // Diferir disposal al siguiente frame para que los TextFormField
    // del dialog terminen de desmontarse antes de liberar los controllers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      identificadorController.dispose();
      cedulaController.dispose();
      nombreUsuarioController.dispose();
      nombresController.dispose();
      apellidosController.dispose();
      passwordController.dispose();
      emailController.dispose();
      telefonoController.dispose();
      celularController.dispose();
      direccionController.dispose();
    });

    if (saved == true && mounted) {
      _showFeedback(
        user == null
            ? 'Usuario creado correctamente'
            : 'Usuario actualizado correctamente',
        color: AppColors.success,
      );
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar usuario'),
          content: Text(
            '¿Seguro que deseas eliminar a ${user.nombreUsuario}? Esta accion no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _repository.deleteUser(user.id);
    if (!mounted) return;
    _showFeedback('Usuario eliminado correctamente', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: () {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isSuper = auth.rol.toLowerCase() == 'superadmin';
        return isSuper
            ? _repository.watchUsers()
            : _repository.watchByTenant(auth.tenantId);
      }(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar la lista de usuarios: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!;
        // Actualizar la caché fuera de la fase build para evitar
        // mutaciones de estado durante el render (child.owner assertion).
        if (_cachedUsers != users) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _cachedUsers = users);
          });
        }
        final filteredUsers = _filterUsers(users);
        final activeUsers = users.where((user) => user.estadoActivo).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 980;

            return AdminModuleShell(
              title: 'Clientes y Usuarios',
              subtitle:
                  'Gestiona registros del sistema con una interfaz administrativa pensada para escritorio.',
              metricChips: [
                AdminMetricChip(
                  label: 'Usuarios',
                  value: users.length.toString(),
                ),
                AdminMetricChip(
                  label: 'Activos',
                  value: activeUsers.toString(),
                  color: AppColors.success,
                ),
              ],
              primaryAction: AdminPrimaryButton(
                label: 'Nuevo',
                icon: Icons.add,
                onPressed: _openUserForm,
              ),
              filters: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isWide ? 360 : double.infinity,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F9FC),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar por cedula, usuario, nombre o correo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F9FC),
                        border: OutlineInputBorder(),
                        labelText: 'Mostrar',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'superadmin',
                          child: Text('superadmin'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                        DropdownMenuItem(
                          value: 'vendedor',
                          child: Text('vendedor'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedRole = value);
                      },
                    ),
                  ),
                ],
              ),
              content: users.isEmpty
                  ? const Center(
                      child: Text('No hay usuarios registrados todavia.'),
                    )
                  : filteredUsers.isEmpty
                      ? const Center(
                          child:
                              Text('No hay resultados para el filtro actual.'),
                        )
                      : AdminTableCard(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return _UserRowCard(
                                user: user,
                                isWide: isWide,
                                formatDate: _formatDate,
                                onEdit: () => _openUserForm(user),
                                onDelete: () => _deleteUser(user),
                              );
                            },
                          ),
                        ),
            );
          },
        );
      },
    );
  }
}

class _UserRowCard extends StatelessWidget {
  const _UserRowCard({
    required this.user,
    required this.isWide,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  final AppUser user;
  final bool isWide;
  final String Function(DateTime?) formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: isWide
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _PrimaryUserCell(
                      user: user,
                      formatDate: formatDate,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('${user.nombres} ${user.apellidos}'.trim()),
                  ),
                  Expanded(
                    flex: 2,
                    child: _TagChip(label: user.rol, color: AppColors.primary),
                  ),
                  Expanded(
                    flex: 2,
                    child: _TagChip(
                      label: user.estadoActivo ? 'Activo' : 'Inactivo',
                      color: user.estadoActivo
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrimaryUserCell(user: user, formatDate: formatDate),
                  const SizedBox(height: 12),
                  Text('${user.nombres} ${user.apellidos}'.trim()),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TagChip(label: user.rol, color: AppColors.primary),
                      _TagChip(
                        label: user.estadoActivo ? 'Activo' : 'Inactivo',
                        color: user.estadoActivo
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrimaryUserCell extends StatelessWidget {
  const _PrimaryUserCell({required this.user, required this.formatDate});

  final AppUser user;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor:
              user.estadoActivo ? AppColors.success : AppColors.error,
          foregroundColor: Colors.white,
          child: Text(
            user.nombreUsuario.isNotEmpty
                ? user.nombreUsuario[0].toUpperCase()
                : '?',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (user.identificador.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.identificador,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      user.nombreUsuario,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (user.cedula.isNotEmpty)
                Text(
                  'Cédula: ${user.cedula}',
                  style: TextStyle(color: Colors.blueGrey.shade700),
                ),
              if ((user.email ?? '').isNotEmpty)
                Text(
                  user.email!,
                  style: TextStyle(color: Colors.blueGrey.shade700),
                ),
              Text(
                'Creado: ${formatDate(user.fechaCreacion)}',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _WarnRow extends StatelessWidget {
  const _WarnRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded,
            size: 15, color: Colors.amber.shade800),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber.shade900,
            ),
          ),
        ),
      ],
    );
  }
}
