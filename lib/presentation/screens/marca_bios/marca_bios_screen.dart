// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
// dart:html disponible solo en Flutter Web
// ignore: uri_does_not_exist
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/marca_bios.dart';
import 'package:inventario_app/data/models/usuario_bios.dart';
import 'package:inventario_app/data/repositories/marca_bios_repository.dart';
import 'package:inventario_app/data/repositories/usuario_bios_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/widgets/admin_module_ui.dart';
import 'package:inventario_app/presentation/widgets/material_color_picker.dart';

class MarcaBiosScreen extends StatefulWidget {
  const MarcaBiosScreen({super.key});

  @override
  State<MarcaBiosScreen> createState() => _MarcaBiosScreenState();
}

class _MarcaBiosScreenState extends State<MarcaBiosScreen> {
  final _repo = MarcaBiosRepository();
  final _negocioRepo = UsuarioBiosRepository();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtrado ─────────────────────────────────────────────

  List<MarcaBios> _filter(List<MarcaBios> all) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((m) => m.nombreNegocio.toLowerCase().contains(q)).toList();
  }

  // ── Parseo de color HEX a Color ──────────────────────────

  static Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      if (h.length == 8) return Color(int.parse(h, radix: 16));
    } catch (_) {}
    return AppColors.primary;
  }

  // ── Dialogo Crear / Editar ────────────────────────────────

  Future<void> _openForm([MarcaBios? marca]) async {
    final auditor = context.mounted
        ? Provider.of<AuthProvider>(context, listen: false).nombreUsuario
        : 'BIOS';

    List<UsuarioBios> negocios = [];
    try {
      negocios = await _negocioRepo
          .watchAll()
          .first
          .then((list) => list.where((n) => n.estadoActivo).toList());
    } catch (_) {}
    if (!mounted) return;

    UsuarioBios? selectedNegocio = marca == null
        ? (negocios.isNotEmpty ? negocios.first : null)
        : negocios.cast<UsuarioBios?>().firstWhere(
              (n) => n?.id == marca.negocioId,
              orElse: () => negocios.isNotEmpty ? negocios.first : null,
            );

    final colorPrimCtrl =
        TextEditingController(text: marca?.colorPrimario ?? '#1E2E51');
    final cromCtrls = (marca?.cromatica ?? [])
        .map((h) => TextEditingController(text: h))
        .toList();

    String? logoBase64 = marca?.logoBase64;
    String? logoFormato = marca?.logoFormato;
    final formKey = GlobalKey<FormState>();
    String activeTarget = 'primario';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // ── Logo picker ──────────────────────────────
          void pickLogo() {
            if (!kIsWeb) return;
            final input = html.FileUploadInputElement()
              ..accept = 'image/png,image/jpeg,image/jpg,image/bmp';
            input.click();
            input.onChange.listen((_) {
              final file = input.files?.first;
              if (file == null) return;
              final reader = html.FileReader();
              reader.readAsDataUrl(file);
              reader.onLoad.listen((_) {
                final result = reader.result as String;
                final b64 =
                    result.contains(',') ? result.split(',').last : result;
                final fmt = file.type.contains('/')
                    ? file.type.split('/').last.replaceAll('jpeg', 'jpg')
                    : 'png';
                setDlg(() {
                  logoBase64 = b64;
                  logoFormato = fmt;
                });
              });
            });
          }

          // ── Paleta → actualizar campo activo ─────────
          void onPaletteColor(String hex) {
            setDlg(() {
              if (activeTarget == 'primario') {
                colorPrimCtrl.text = hex;
              } else {
                final idx = int.tryParse(activeTarget);
                if (idx != null && idx < cromCtrls.length) {
                  cromCtrls[idx].text = hex;
                }
              }
            });
          }

          String activeLabel() {
            if (activeTarget == 'primario') return 'Color Primario';
            final idx = int.tryParse(activeTarget);
            if (idx != null) return 'Cromática #${idx + 1}';
            return 'Color Primario';
          }

          String activeHex() {
            if (activeTarget == 'primario') return colorPrimCtrl.text.trim();
            final idx = int.tryParse(activeTarget);
            if (idx != null && idx < cromCtrls.length) {
              return cromCtrls[idx].text.trim();
            }
            return colorPrimCtrl.text.trim();
          }

          return AdminFormDialog(
            title: marca == null ? 'Nueva Marca' : 'Editar Marca',
            body: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Selector de negocio ─────────────
                  const Text('Negocio asociado',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  negocios.isEmpty
                      ? const Text(
                          'No hay negocios activos. Crea uno en "Negocios BIOS" primero.',
                          style: TextStyle(color: Colors.red),
                        )
                      : DropdownButtonFormField<UsuarioBios>(
                          value: selectedNegocio,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: negocios
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text(n.nombreNegocio),
                                  ))
                              .toList(),
                          onChanged: (v) => setDlg(() => selectedNegocio = v),
                          validator: (_) => selectedNegocio == null
                              ? 'Selecciona un negocio'
                              : null,
                        ),

                  const SizedBox(height: 20),

                  // ── Color Primario ──────────────────
                  const Text('Color Primario',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  _ColorFieldRow(
                    label: 'Primario',
                    controller: colorPrimCtrl,
                    isActive: activeTarget == 'primario',
                    hexColor: _hexColor,
                    onTapActivate: () =>
                        setDlg(() => activeTarget = 'primario'),
                    onChanged: () => setDlg(() {}),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),

                  const SizedBox(height: 20),

                  // ── Cromática ───────────────────────
                  Row(
                    children: [
                      const Text('Cromática / Paleta secundaria',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          final ctrl = TextEditingController(text: '#FFFFFF');
                          cromCtrls.add(ctrl);
                          setDlg(
                              () => activeTarget = '${cromCtrls.length - 1}');
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Añadir',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (cromCtrls.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Sin colores secundarios. Usa "Añadir" para agregar.',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ),
                  ...cromCtrls.asMap().entries.map((e) {
                    final i = e.key;
                    final ctrl = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ColorFieldRow(
                        label: '#${i + 1}',
                        controller: ctrl,
                        isActive: activeTarget == '$i',
                        hexColor: _hexColor,
                        onTapActivate: () => setDlg(() => activeTarget = '$i'),
                        onChanged: () => setDlg(() {}),
                        onDelete: () {
                          ctrl.dispose();
                          cromCtrls.removeAt(i);
                          setDlg(() {
                            if (activeTarget == '$i') {
                              activeTarget = 'primario';
                            }
                          });
                        },
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── Paleta Material Design (siempre visible) ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDE3EF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.palette_outlined,
                                size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              'Paleta → ${activeLabel()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _hexColor(activeHex()),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: const Color(0xFFDDE3EF)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              activeHex().toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MaterialColorPicker(
                          selectedHex: activeHex(),
                          onColorSelected: onPaletteColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Logo ────────────────────────────
                  const Text('Logo del negocio',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const SizedBox(height: 4),
                  const Text(
                    'Formatos admitidos: PNG, JPG, JPEG, BMP',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F5FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDE3EF)),
                        ),
                        child: logoBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  base64Decode(logoBase64!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.image_outlined,
                                    size: 36, color: Colors.black26),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminPrimaryButton(
                            label: 'Seleccionar imagen',
                            icon: Icons.upload_outlined,
                            onPressed: pickLogo,
                          ),
                          if (logoBase64 != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Formato: ${logoFormato?.toUpperCase() ?? '?'}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                            TextButton.icon(
                              onPressed: () => setDlg(() => logoBase64 = null),
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              label: const Text('Quitar logo',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.red)),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              AdminPrimaryButton(
                label: 'Guardar',
                icon: Icons.save_outlined,
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (selectedNegocio == null) return;
                  final nueva = MarcaBios(
                    id: marca?.id ?? '',
                    negocioId: selectedNegocio!.id,
                    nombreNegocio: selectedNegocio!.nombreNegocio,
                    colorPrimario: colorPrimCtrl.text.trim(),
                    cromatica: cromCtrls
                        .map((c) => c.text.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(),
                    logoBase64: logoBase64,
                    logoFormato: logoFormato,
                    fechaCreacion: marca?.fechaCreacion ?? DateTime.now(),
                    creadoPor: marca?.creadoPor ?? auditor,
                    modificadoPor: auditor,
                  );
                  await _repo.save(nueva);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );

    // Liberar controladores
    colorPrimCtrl.dispose();
    for (final c in cromCtrls) {
      c.dispose();
    }
  }

  // ── Confirmar eliminación ─────────────────────────────────

  Future<void> _confirmDelete(MarcaBios marca) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Marca'),
        content: Text(
            '¿Eliminar la configuración de marca de "${marca.nombreNegocio}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.delete(marca.id);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminModuleShell(
      title: 'MARCA',
      subtitle: 'Manual de marca y cromatica por negocio',
      primaryAction: AdminPrimaryButton(
        label: 'Nueva Marca',
        icon: Icons.add,
        onPressed: () => _openForm(),
      ),
      filters: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar negocio...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (_) => setState(() {}),
      ),
      content: StreamBuilder<List<MarcaBios>>(
        stream: _repo.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final all = snap.data ?? [];
          final list = _filter(all);

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.palette_outlined,
                      size: 64, color: Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    all.isEmpty
                        ? 'Sin marcas registradas.\nPresiona "Nueva Marca" para crear la primera.'
                        : 'Sin resultados para la busqueda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(0),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _MarcaRowCard(
              marca: list[i],
              hexColor: _hexColor,
              onEdit: () => _openForm(list[i]),
              onDelete: () => _confirmDelete(list[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Tarjeta de fila ───────────────────────────────────────────

// ── _ColorFieldRow ─────────────────────────────────────────────────────────

class _ColorFieldRow extends StatelessWidget {
  const _ColorFieldRow({
    required this.label,
    required this.controller,
    required this.isActive,
    required this.hexColor,
    required this.onTapActivate,
    required this.onChanged,
    this.validator,
    this.onDelete,
  });

  final String label;
  final TextEditingController controller;
  final bool isActive;
  final Color Function(String) hexColor;
  final VoidCallback onTapActivate;
  final VoidCallback onChanged;
  final String? Function(String?)? validator;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapActivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFDDE3EF),
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isActive ? const Color(0xFFF0F5FF) : Colors.white,
        ),
        child: Row(
          children: [
            if (label.isNotEmpty && label != 'Primario') ...[
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
            ],
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hexColor(controller.text),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDE3EF)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: validator != null
                  ? TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: isActive
                            ? const Icon(Icons.colorize,
                                size: 16, color: Color(0xFF2563EB))
                            : null,
                      ),
                      onTap: onTapActivate,
                      onChanged: (_) => onChanged(),
                      validator: validator,
                    )
                  : TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: isActive
                            ? const Icon(Icons.colorize,
                                size: 16, color: Color(0xFF2563EB))
                            : null,
                      ),
                      onTap: onTapActivate,
                      onChanged: (_) => onChanged(),
                    ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
        ),
      ),
    );
  }
}

// ── _MarcaRowCard ───────────────────────────────────────────────────────────

class _MarcaRowCard extends StatelessWidget {
  const _MarcaRowCard({
    required this.marca,
    required this.hexColor,
    required this.onEdit,
    required this.onDelete,
  });

  final MarcaBios marca;
  final Color Function(String) hexColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminTableCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Logo o ícono ────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hexColor(marca.colorPrimario).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE3EF)),
            ),
            child: marca.logoBase64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(marca.logoBase64!),
                      fit: BoxFit.contain,
                    ),
                  )
                : Icon(Icons.store_outlined,
                    color: hexColor(marca.colorPrimario), size: 28),
          ),

          const SizedBox(width: 14),

          // ── Info ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marca.nombreNegocio,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Chip color primario
                    _ColorChip(
                        hex: marca.colorPrimario,
                        hexColor: hexColor,
                        label: 'Primario'),
                    const SizedBox(width: 6),
                    // Cromática
                    ...marca.cromatica.take(5).map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Tooltip(
                              message: h,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: hexColor(h),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFDDE3EF)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    if (marca.cromatica.length > 5)
                      Text(
                        '+${marca.cromatica.length - 5}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                  ],
                ),
                if (marca.logoFormato != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Logo: ${marca.logoFormato!.toUpperCase()}',
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ],
            ),
          ),

          // ── Acciones ────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                tooltip: 'Editar',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Eliminar',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget chip de color ──────────────────────────────────────

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.hex,
    required this.hexColor,
    required this.label,
  });

  final String hex;
  final Color Function(String) hexColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hexColor(hex).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hexColor(hex).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: hexColor(hex),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label $hex',
            style: TextStyle(
              fontSize: 11,
              color: hexColor(hex),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
