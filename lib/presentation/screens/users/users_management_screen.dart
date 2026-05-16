import 'package:flutter/material.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/app_user.dart';
import 'package:inventario_app/data/repositories/user_repository.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final UserRepository _repository = UserRepository();
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filterUsers(List<AppUser> users) {
    final query = _searchController.text.trim().toLowerCase();

    return users.where((user) {
      final matchesRole =
          _selectedRole == 'todos' || user.rol.toLowerCase() == _selectedRole;
      final matchesQuery = query.isEmpty ||
          user.nombreUsuario.toLowerCase().contains(query) ||
          user.nombres.toLowerCase().contains(query) ||
          user.rol.toLowerCase().contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  Future<void> _openUserForm([AppUser? user]) async {
    final nombreUsuarioController =
        TextEditingController(text: user?.nombreUsuario ?? '');
    final nombresController = TextEditingController(text: user?.nombres ?? '');
    final passwordController =
        TextEditingController(text: user?.password ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final telefonoController =
        TextEditingController(text: user?.telefono ?? '');
    String rol = user?.rol ?? 'vendedor';
    bool estadoActivo = user?.estadoActivo ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(user == null ? 'Nuevo usuario' : 'Editar usuario'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreUsuarioController,
                          decoration:
                              const InputDecoration(labelText: 'Usuario'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ingresa el usuario'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nombresController,
                          decoration:
                              const InputDecoration(labelText: 'Nombres'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ingresa el nombre'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          decoration:
                              const InputDecoration(labelText: 'Contraseña'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ingresa la contraseña'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: telefonoController,
                          decoration:
                              const InputDecoration(labelText: 'Teléfono'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: rol,
                          decoration: const InputDecoration(labelText: 'Rol'),
                          items: const [
                            DropdownMenuItem(
                                value: 'superadmin', child: Text('superadmin')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('admin')),
                            DropdownMenuItem(
                                value: 'vendedor', child: Text('vendedor')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => rol = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Usuario activo'),
                          value: estadoActivo,
                          onChanged: (value) {
                            setDialogState(() => estadoActivo = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final draft = AppUser(
                      id: user?.id ?? '',
                      nombreUsuario: nombreUsuarioController.text,
                      nombres: nombresController.text,
                      password: passwordController.text,
                      rol: rol,
                      estadoActivo: estadoActivo,
                      email: emailController.text.isEmpty
                          ? null
                          : emailController.text,
                      telefono: telefonoController.text.isEmpty
                          ? null
                          : telefonoController.text,
                    );

                    if (user == null) {
                      await _repository.createUser(draft);
                    } else {
                      await _repository.updateUser(draft);
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nombreUsuarioController.dispose();
    nombresController.dispose();
    passwordController.dispose();
    emailController.dispose();
    telefonoController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user == null
              ? 'Usuario creado correctamente'
              : 'Usuario actualizado correctamente'),
        ),
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
              '¿Seguro que deseas eliminar a ${user.nombreUsuario}? Esta acción no se puede deshacer.'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario eliminado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Gestión de usuarios'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUserForm,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _repository.watchUsers(),
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
          final filteredUsers = _filterUsers(users);

          if (users.isEmpty) {
            return const Center(
              child: Text('No hay usuarios registrados todavía.'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por usuario, nombre o rol',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          labelText: 'Rol',
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'todos', child: Text('Todos')),
                          DropdownMenuItem(
                              value: 'superadmin', child: Text('superadmin')),
                          DropdownMenuItem(
                              value: 'admin', child: Text('admin')),
                          DropdownMenuItem(
                              value: 'vendedor', child: Text('vendedor')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedRole = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredUsers.isEmpty
                    ? const Center(
                        child: Text('No hay resultados para el filtro actual.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: user.estadoActivo
                                    ? AppColors.success
                                    : AppColors.error,
                                foregroundColor: Colors.white,
                                child: Text(
                                  user.nombreUsuario.isNotEmpty
                                      ? user.nombreUsuario[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(user.nombreUsuario),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(user.nombres),
                                  const SizedBox(height: 4),
                                  Text('Rol: ${user.rol}'),
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _openUserForm(user),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () => _deleteUser(user),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
