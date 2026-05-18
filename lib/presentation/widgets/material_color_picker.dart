import 'package:flutter/material.dart';

/// Paleta Material Design completa: 19 familias × 10 tonos.
/// Callback [onColorSelected] recibe el hex del color elegido (ej. "#F44336").
class MaterialColorPicker extends StatelessWidget {
  const MaterialColorPicker({
    super.key,
    required this.onColorSelected,
    this.selectedHex,
  });

  final void Function(String hex) onColorSelected;

  /// Hex actualmente seleccionado, para resaltarlo en la paleta.
  final String? selectedHex;

  // ── Paleta estática ────────────────────────────────────────

  static final _families = <_ColorFamily>[
    _ColorFamily('Red', Colors.red),
    _ColorFamily('Pink', Colors.pink),
    _ColorFamily('Purple', Colors.purple),
    _ColorFamily('D.Purple', Colors.deepPurple),
    _ColorFamily('Indigo', Colors.indigo),
    _ColorFamily('Blue', Colors.blue),
    _ColorFamily('L.Blue', Colors.lightBlue),
    _ColorFamily('Cyan', Colors.cyan),
    _ColorFamily('Teal', Colors.teal),
    _ColorFamily('Green', Colors.green),
    _ColorFamily('L.Green', Colors.lightGreen),
    _ColorFamily('Lime', Colors.lime),
    _ColorFamily('Yellow', Colors.yellow),
    _ColorFamily('Amber', Colors.amber),
    _ColorFamily('Orange', Colors.orange),
    _ColorFamily('D.Orange', Colors.deepOrange),
    _ColorFamily('Brown', Colors.brown),
    _ColorFamily('Grey', Colors.grey),
    _ColorFamily('B.Grey', Colors.blueGrey),
  ];

  static const _shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];

  // ── Utilidades ────────────────────────────────────────────

  static String toHex(Color c) {
    return '#'
            '${c.red.toRadixString(16).padLeft(2, '0')}'
            '${c.green.toRadixString(16).padLeft(2, '0')}'
            '${c.blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  /// Devuelve true si el color es oscuro (para elegir texto blanco o negro).
  static bool _isDark(Color c) =>
      (c.red * 0.299 + c.green * 0.587 + c.blue * 0.114) < 128;

  @override
  Widget build(BuildContext context) {
    final selNorm = selectedHex?.toUpperCase().trim();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDE3EF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _families.map((family) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Nombre de familia ─────────────
                  Container(
                    width: 32,
                    height: 20,
                    color: const Color(0xFFF2F5FA),
                    alignment: Alignment.center,
                    child: Text(
                      family.name,
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF455A64),
                      ),
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                    ),
                  ),
                  // ── Tonos ─────────────────────────
                  ..._shades.map((shade) {
                    final color = family.material[shade]!;
                    final hex = toHex(color);
                    final isSelected = selNorm == hex;
                    return Tooltip(
                      message: '${family.name} $shade  $hex',
                      waitDuration: const Duration(milliseconds: 400),
                      child: GestureDetector(
                        onTap: () => onColorSelected(hex),
                        child: Container(
                          width: 32,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            border: isSelected
                                ? Border.all(color: Colors.black87, width: 2.5)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 10,
                                  color: _isDark(color)
                                      ? Colors.white
                                      : Colors.black87,
                                )
                              : Text(
                                  shade == 50 ? '50' : '${shade ~/ 100}',
                                  style: TextStyle(
                                    fontSize: 7,
                                    color: _isDark(color)
                                        ? Colors.white54
                                        : Colors.black38,
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ColorFamily {
  final String name;
  final MaterialColor material;
  const _ColorFamily(this.name, this.material);
}
