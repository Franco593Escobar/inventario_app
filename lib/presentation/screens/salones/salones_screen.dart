import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/core/constants/app_colors.dart';
import 'package:inventario_app/data/models/salon.dart';
import 'package:inventario_app/data/repositories/salon_repository.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

class SalonesScreen extends StatefulWidget {
  const SalonesScreen({super.key});

  @override
  State<SalonesScreen> createState() => _SalonesScreenState();
}

class _SalonesScreenState extends State<SalonesScreen> {
  final SalonRepository _repo = SalonRepository();
  String? _tenantIdForStream;
  Stream<List<Salon>>? _salonesStream;

  void _ensureTenantStream(String tenantId) {
    if (_tenantIdForStream == tenantId && _salonesStream != null) return;
    _tenantIdForStream = tenantId;
    _salonesStream = _repo.watchAllByTenant(tenantId);
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = context.select<AuthProvider, String>((a) => a.tenantId);
    _ensureTenantStream(tenantId);
    final salonesStream = _salonesStream;
    if (salonesStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Salones & Mesas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _showSalonDialog(context, tenantId, _repo),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo Salón'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Salon>>(
        stream: salonesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final salones = snap.data ?? [];
          if (salones.isEmpty) {
            return _EmptyState(
              onAdd: () => _showSalonDialog(context, tenantId, _repo),
            );
          }
          return _SalonesListView(
            salones: salones,
            tenantId: tenantId,
            repo: _repo,
          );
        },
      ),
    );
  }

  void _showSalonDialog(
      BuildContext context, String tenantId, SalonRepository repo,
      {Salon? salon}) {
    showDialog(
      context: context,
      builder: (_) => _SalonDialog(
        tenantId: tenantId,
        repo: repo,
        salon: salon,
      ),
    );
  }
}

// ─── Lista de Salones ─────────────────────────────────────────────────────────

class _SalonesListView extends StatelessWidget {
  const _SalonesListView({
    required this.salones,
    required this.tenantId,
    required this.repo,
  });
  final List<Salon> salones;
  final String tenantId;
  final SalonRepository repo;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: salones.length,
      itemBuilder: (ctx, i) {
        final salon = salones[i];
        return _SalonCard(
          salon: salon,
          tenantId: tenantId,
          repo: repo,
        );
      },
    );
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({
    required this.salon,
    required this.tenantId,
    required this.repo,
  });
  final Salon salon;
  final String tenantId;
  final SalonRepository repo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: salon.activo
                ? AppColors.primary.withOpacity(0.12)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.table_restaurant,
            color: salon.activo ? AppColors.primary : Colors.grey,
          ),
        ),
        title: Text(
          salon.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${salon.mesasActivas} mesa(s) activa(s)'
          '${salon.descripcion.isNotEmpty ? ' · ${salon.descripcion}' : ''}',
          style: TextStyle(
              color: salon.activo ? Colors.black54 : Colors.grey, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Activo/inactivo chip
            Switch(
              value: salon.activo,
              activeColor: AppColors.accent,
              onChanged: (val) async {
                await repo.update(salon.copyWith(activo: val));
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _SalonDialog(
                  tenantId: tenantId,
                  repo: repo,
                  salon: salon,
                ),
              ),
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          _MesasGrid(salon: salon, repo: repo, tenantId: tenantId),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar salón'),
        content: Text(
            '¿Seguro que deseas eliminar "${salon.nombre}"? Esta acción es irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await repo.delete(tenantId, salon.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ─── Grid de Mesas ────────────────────────────────────────────────────────────

class _MesasGrid extends StatelessWidget {
  const _MesasGrid({
    required this.salon,
    required this.repo,
    required this.tenantId,
  });
  final Salon salon;
  final SalonRepository repo;
  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mesas (${salon.mesas.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddMesaDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar mesa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (salon.mesas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay mesas configuradas. Agrega la primera.',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: salon.mesas
                  .map((m) => _MesaChip(
                        mesa: m,
                        onEdit: () => _showEditMesaDialog(context, m),
                        onToggle: () async {
                          final updated = salon.mesas
                              .map((x) => x.numero == m.numero
                                  ? x.copyWith(activa: !x.activa)
                                  : x)
                              .toList();
                          await repo.update(salon.copyWith(mesas: updated));
                        },
                        onDelete: () async {
                          final updated = salon.mesas
                              .where((x) => x.numero != m.numero)
                              .toList();
                          await repo.update(salon.copyWith(mesas: updated));
                        },
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _showAddMesaDialog(BuildContext context) {
    final numCtrl = TextEditingController(
        text: '${salon.mesas.isEmpty ? 1 : salon.mesas.last.numero + 1}');
    final nombreCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '4');
    showDialog(
      context: context,
      builder: (_) => _MesaDialog(
        title: 'Agregar Mesa',
        numCtrl: numCtrl,
        nombreCtrl: nombreCtrl,
        capCtrl: capCtrl,
        onSave: () async {
          final num = int.tryParse(numCtrl.text) ?? 1;
          final nombre = nombreCtrl.text.trim().isNotEmpty
              ? nombreCtrl.text.trim()
              : 'Mesa $num';
          final cap = int.tryParse(capCtrl.text) ?? 4;
          // Verificar no duplicado
          if (salon.mesas.any((m) => m.numero == num)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('La mesa número $num ya existe en este salón')),
            );
            return;
          }
          final updated = [
            ...salon.mesas,
            Mesa(numero: num, nombre: nombre, capacidad: cap),
          ]..sort((a, b) => a.numero.compareTo(b.numero));
          await repo.update(salon.copyWith(mesas: updated));
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditMesaDialog(BuildContext context, Mesa mesa) {
    final numCtrl = TextEditingController(text: '${mesa.numero}');
    final nombreCtrl = TextEditingController(text: mesa.nombre);
    final capCtrl = TextEditingController(text: '${mesa.capacidad}');
    showDialog(
      context: context,
      builder: (_) => _MesaDialog(
        title: 'Editar Mesa',
        numCtrl: numCtrl,
        nombreCtrl: nombreCtrl,
        capCtrl: capCtrl,
        onSave: () async {
          final num = int.tryParse(numCtrl.text) ?? mesa.numero;
          final nombre = nombreCtrl.text.trim().isNotEmpty
              ? nombreCtrl.text.trim()
              : 'Mesa $num';
          final cap = int.tryParse(capCtrl.text) ?? 4;
          final updated = salon.mesas
              .map((m) => m.numero == mesa.numero
                  ? Mesa(
                      numero: num,
                      nombre: nombre,
                      capacidad: cap,
                      activa: m.activa)
                  : m)
              .toList();
          await repo.update(salon.copyWith(mesas: updated));
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _MesaChip extends StatelessWidget {
  const _MesaChip({
    required this.mesa,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final Mesa mesa;
  final VoidCallback onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: mesa.activa ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: mesa.activa ? Colors.green.shade200 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_restaurant_outlined,
              size: 14,
              color: mesa.activa ? Colors.green.shade700 : Colors.grey),
          const SizedBox(width: 4),
          Text(
            mesa.nombre,
            style: TextStyle(
                fontSize: 12,
                color: mesa.activa ? Colors.green.shade800 : Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit, size: 13, color: Colors.blueGrey),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 13, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────

class _MesaDialog extends StatelessWidget {
  const _MesaDialog({
    required this.title,
    required this.numCtrl,
    required this.nombreCtrl,
    required this.capCtrl,
    required this.onSave,
  });
  final String title;
  final TextEditingController numCtrl, nombreCtrl, capCtrl;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: numCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Número de mesa', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                hintText: 'Ej: Terraza 1',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: capCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Capacidad (personas)',
                border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SalonDialog extends StatefulWidget {
  const _SalonDialog({
    required this.tenantId,
    required this.repo,
    this.salon,
  });
  final String tenantId;
  final SalonRepository repo;
  final Salon? salon;

  @override
  State<_SalonDialog> createState() => _SalonDialogState();
}

class _SalonDialogState extends State<_SalonDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.salon?.nombre ?? '');
    _descCtrl = TextEditingController(text: widget.salon?.descripcion ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.salon == null) {
        await widget.repo.create(
          Salon(
            id: '',
            tenantId: widget.tenantId,
            nombre: nombre,
            descripcion: _descCtrl.text.trim(),
          ),
        );
      } else {
        await widget.repo.update(
          widget.salon!.copyWith(
            nombre: nombre,
            descripcion: _descCtrl.text.trim(),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.salon == null ? 'Nuevo Salón' : 'Editar Salón'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del salón *',
              hintText: 'Ej: Salón Principal, Terraza',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_restaurant, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No hay salones configurados',
              style: TextStyle(fontSize: 18, color: Colors.black45)),
          const SizedBox(height: 8),
          const Text(
              'Crea salones (Terraza, Salón Principal, etc.) y asígnales mesas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Crear primer salón'),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
