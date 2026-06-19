import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/proveedor.dart';
import 'package:inventario_app/data/repositories/proveedor_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final ProveedorRepository _repository = ProveedorRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Proveedor> _cachedProveedores = [];
  Stream<List<Proveedor>>? _proveedoresStream;
  String _proveedoresTenantId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tenantId = Provider.of<AuthProvider>(context, listen: false).tenantId;
    if (_proveedoresStream == null || _proveedoresTenantId != tenantId) {
      _proveedoresTenantId = tenantId;
      _proveedoresStream = _repository.watchByTenant(tenantId);
    }
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
          return 'No se pudo $action: Firestore denegó la escritura.';
        case 'unavailable':
          return 'No se pudo $action: servicio no disponible.';
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

  List<Proveedor> _filterProveedores(List<Proveedor> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((p) {
      return p.nombre.toLowerCase().contains(query) ||
          p.ruc.toLowerCase().contains(query) ||
          p.identificador.toLowerCase().contains(query) ||
          (p.telefono ?? '').toLowerCase().contains(query) ||
          (p.email ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openForm([Proveedor? proveedor]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final auditor = auth.nombreUsuario;
    final tenantId = auth.tenantId;

    final identCtrl =
        TextEditingController(text: proveedor?.identificador ?? '');
    final nombreCtrl = TextEditingController(text: proveedor?.nombre ?? '');
    final rucCtrl = TextEditingController(text: proveedor?.ruc ?? '');
    final telCtrl = TextEditingController(text: proveedor?.telefono ?? '');
    final emailCtrl = TextEditingController(text: proveedor?.email ?? '');
    final dirCtrl = TextEditingController(text: proveedor?.direccion ?? '');
    final contactoCtrl = TextEditingController(text: proveedor?.contacto ?? '');
    bool activo = proveedor?.activo ?? true;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? submitError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AdminFormDialog(
            title: proveedor == null ? 'Nuevo Proveedor' : 'Editar Proveedor',
            body: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _field(identCtrl, 'IDENTIFICADOR *', 'P001',
                          required: true),
                      _field(nombreCtrl, 'NOMBRE / RAZÓN SOCIAL *', '',
                          required: true),
                      _field(rucCtrl, 'RUC / CÉDULA', ''),
                      _field(telCtrl, 'TELÉFONO', ''),
                      _field(emailCtrl, 'EMAIL', '',
                          keyboardType: TextInputType.emailAddress),
                      _field(dirCtrl, 'DIRECCIÓN', '', fullWidth: true),
                      _field(contactoCtrl, 'PERSONA DE CONTACTO', ''),
                      _switchRow('Estado', activo,
                          (v) => setDialogState(() => activo = v)),
                    ],
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
                      child: Text(submitError!,
                          style: TextStyle(color: Colors.red.shade900)),
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
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() {
                    isSubmitting = true;
                    submitError = null;
                  });
                  final draft = Proveedor(
                    id: proveedor?.id ?? '',
                    tenantId: proveedor?.tenantId ?? tenantId,
                    identificador: identCtrl.text.trim(),
                    nombre: nombreCtrl.text.trim(),
                    ruc: rucCtrl.text.trim(),
                    activo: activo,
                    telefono: telCtrl.text.trim().isEmpty
                        ? null
                        : telCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty
                        ? null
                        : emailCtrl.text.trim(),
                    direccion: dirCtrl.text.trim().isEmpty
                        ? null
                        : dirCtrl.text.trim(),
                    contacto: contactoCtrl.text.trim().isEmpty
                        ? null
                        : contactoCtrl.text.trim(),
                    fechaCreacion: proveedor?.fechaCreacion ?? DateTime.now(),
                    creadoPor: proveedor?.creadoPor ?? auditor,
                    modificadoPor: auditor,
                  );
                  try {
                    if (proveedor == null) {
                      await _repository.create(draft);
                    } else {
                      await _repository.update(draft);
                    }
                  } catch (e) {
                    setDialogState(() {
                      isSubmitting = false;
                      submitError = _formatFirestoreError(
                          e, proveedor == null ? 'crear' : 'actualizar');
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
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      identCtrl.dispose();
      nombreCtrl.dispose();
      rucCtrl.dispose();
      telCtrl.dispose();
      emailCtrl.dispose();
      dirCtrl.dispose();
      contactoCtrl.dispose();
    });

    if (saved == true && mounted) {
      _showFeedback(
        proveedor == null
            ? 'Proveedor creado correctamente'
            : 'Proveedor actualizado correctamente',
        color: AppColors.success,
      );
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool required = false,
    bool fullWidth = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : 280,
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
            : null,
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 280,
      child: SwitchListTile.adaptive(
        title: Text(label),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _deleteProveedor(Proveedor p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text(
            '¿Seguro que deseas eliminar a ${p.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.delete(p.id);
    if (!mounted) return;
    _showFeedback('Proveedor eliminado', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _proveedoresStream;
    if (stream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Proveedor>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error al cargar proveedores: ${snapshot.error}',
                      textAlign: TextAlign.center)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data!;
        if (_cachedProveedores != all) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _cachedProveedores = all);
          });
        }
        final filtered = _filterProveedores(all);
        final activos = all.where((p) => p.activo).length;

        return LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 980;

          return AdminModuleShell(
            title: 'Proveedores',
            subtitle: 'Gestiona los proveedores de tu negocio.',
            metricChips: [
              AdminMetricChip(label: 'Total', value: all.length.toString()),
              AdminMetricChip(
                  label: 'Activos',
                  value: activos.toString(),
                  color: AppColors.success),
            ],
            primaryAction: AdminPrimaryButton(
              label: 'Nuevo',
              icon: Icons.add,
              onPressed: _openForm,
            ),
            filters: Wrap(
              spacing: 12,
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
                      hintText: 'Buscar por nombre, RUC o teléfono',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            content: AdminTableCard(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('NOMBRE / RAZÓN')),
                    DataColumn(label: Text('RUC / CÉD.')),
                    DataColumn(label: Text('TELÉFONO')),
                    DataColumn(label: Text('EMAIL')),
                    DataColumn(label: Text('ESTADO')),
                    DataColumn(label: Text('ACCIONES')),
                  ],
                  rows: filtered.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p.identificador,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13))),
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (p.contacto != null)
                            Text(p.contacto!,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                        ],
                      )),
                      DataCell(Text(p.ruc.isEmpty ? '—' : p.ruc)),
                      DataCell(Text(p.telefono ?? '—')),
                      DataCell(Text(p.email ?? '—')),
                      DataCell(Switch.adaptive(
                        value: p.activo,
                        activeColor: AppColors.success,
                        onChanged: (v) async {
                          await _repository.update(p.copyWith(activo: v));
                        },
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Editar',
                            onPressed: () => _openForm(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            tooltip: 'Eliminar',
                            onPressed: () => _deleteProveedor(p),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
