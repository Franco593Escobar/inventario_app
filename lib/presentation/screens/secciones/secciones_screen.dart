import 'dart:convert';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/seccion.dart';
import 'package:inventario_app/data/repositories/seccion_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';

class SeccionesScreen extends StatefulWidget {
  const SeccionesScreen({super.key});

  @override
  State<SeccionesScreen> createState() => _SeccionesScreenState();
}

class _SeccionesScreenState extends State<SeccionesScreen> {
  final SeccionRepository _repository = SeccionRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Seccion> _cachedSecciones = [];

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

  List<Seccion> _filterSecciones(List<Seccion> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((s) => s.nombre.toLowerCase().contains(query)).toList();
  }

  Future<void> _openForm([Seccion? seccion]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final auditor = auth.nombreUsuario;
    final tenantId = auth.tenantId;

    final nombreCtrl = TextEditingController(text: seccion?.nombre ?? '');
    final posCtrl =
        TextEditingController(text: seccion?.posicion.toString() ?? '0');
    bool activa = seccion?.activa ?? true;
    String? imgBase64 = seccion?.imagenBase64;
    String? imgFormato = seccion?.imagenFormato;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? submitError;

    Future<void> pickImage(StateSetter setDialogState) async {
      final upload = html.FileUploadInputElement()
        ..accept = 'image/jpeg,image/png,image/webp';
      upload.click();
      await upload.onChange.first;
      final file = upload.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;
      final result = reader.result as String;
      final comma = result.indexOf(',');
      final b64 = result.substring(comma + 1);
      final ext = file.name.split('.').last.toLowerCase();
      setDialogState(() {
        imgBase64 = b64;
        imgFormato = ext;
      });
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AdminFormDialog(
            title: seccion == null ? 'Nueva Sección' : 'Editar Sección',
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
                        width: 280,
                        child: TextFormField(
                          controller: nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'NOMBRE *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obligatorio'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: posCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'POSICIÓN',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 280,
                        child: SwitchListTile.adaptive(
                          title: const Text('Activa'),
                          value: activa,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setDialogState(() => activa = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Imagen
                  const Text('IMAGEN DE SECCIÓN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (imgBase64 != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(imgBase64!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => pickImage(setDialogState),
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(imgBase64 == null
                            ? 'Subir imagen'
                            : 'Cambiar imagen'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (imgBase64 != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            imgBase64 = null;
                            imgFormato = null;
                          }),
                          child: const Text('Quitar',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
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
                  final draft = Seccion(
                    id: seccion?.id ?? '',
                    tenantId: seccion?.tenantId ?? tenantId,
                    nombre: nombreCtrl.text.trim(),
                    posicion: int.tryParse(posCtrl.text.trim()) ?? 0,
                    activa: activa,
                    imagenBase64: imgBase64,
                    imagenFormato: imgFormato,
                    fechaCreacion: seccion?.fechaCreacion ?? DateTime.now(),
                    creadoPor: seccion?.creadoPor ?? auditor,
                    modificadoPor: auditor,
                  );
                  try {
                    if (seccion == null) {
                      await _repository.create(draft);
                    } else {
                      await _repository.update(draft);
                    }
                  } catch (e) {
                    setDialogState(() {
                      isSubmitting = false;
                      submitError = _formatFirestoreError(
                          e, seccion == null ? 'crear' : 'actualizar');
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
      nombreCtrl.dispose();
      posCtrl.dispose();
    });

    if (saved == true && mounted) {
      _showFeedback(
        seccion == null
            ? 'Sección creada correctamente'
            : 'Sección actualizada correctamente',
        color: AppColors.success,
      );
    }
  }

  Future<void> _deleteSeccion(Seccion s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sección'),
        content: Text(
            '¿Seguro que deseas eliminar "${s.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.delete(s.id);
    if (!mounted) return;
    _showFeedback('Sección eliminada', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = auth.tenantId;

    return StreamBuilder<List<Seccion>>(
      stream: _repository.watchByTenant(tenantId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error al cargar secciones: ${snapshot.error}',
                      textAlign: TextAlign.center)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data!;
        if (_cachedSecciones != all) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _cachedSecciones = all);
          });
        }
        final filtered = _filterSecciones(all);
        final activas = all.where((s) => s.activa).length;

        return LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 980;

          return AdminModuleShell(
            title: 'Secciones',
            subtitle: 'Crea las secciones de tu menú o catálogo.',
            metricChips: [
              AdminMetricChip(label: 'Total', value: all.length.toString()),
              AdminMetricChip(
                  label: 'Activas',
                  value: activas.toString(),
                  color: AppColors.success),
            ],
            primaryAction: AdminPrimaryButton(
              label: 'Nueva',
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
                      hintText: 'Buscar sección',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            content: _buildGrid(filtered),
          );
        });
      },
    );
  }

  Widget _buildGrid(List<Seccion> secciones) {
    if (secciones.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No hay secciones registradas')));
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: secciones
          .map((s) => _SeccionCard(
                seccion: s,
                onEdit: () => _openForm(s),
                onDelete: () => _deleteSeccion(s),
                onToggle: (v) => _repository.update(s.copyWith(activa: v)),
              ))
          .toList(),
    );
  }
}

class _SeccionCard extends StatelessWidget {
  const _SeccionCard({
    required this.seccion,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Seccion seccion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: SizedBox(
          width: 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Imagen o placeholder
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: seccion.imagenBase64 != null
                    ? Image.memory(
                        base64Decode(seccion.imagenBase64!),
                        width: 180,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 180,
                        height: 100,
                        color: const Color(0xFFEEF2FA),
                        child: const Icon(Icons.image_outlined,
                            size: 36, color: Colors.grey),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seccion.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Pos. ${seccion.posicion}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Switch.adaptive(
                          value: seccion.activa,
                          activeColor: AppColors.success,
                          onChanged: onToggle,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Editar',
                              onPressed: onEdit,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              tooltip: 'Eliminar',
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
