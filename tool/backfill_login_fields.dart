import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:inventario_app/firebase_options.dart';

const String _databaseId = 'inventario-bdd';

void _printUsage() {
  print('Backfill de login_username y nombre_usuario_lc en usuarios');
  print('');
  print('Uso:');
  print('  flutter run -d chrome -t tool/backfill_login_fields.dart');
  print('  Variables opcionales por --dart-define:');
  print('    BACKFILL_APPLY=true');
  print('    BACKFILL_TENANT=<id>');
  print('    BACKFILL_LIMIT=<n>');
  print('    BACKFILL_PAGE_SIZE=<n>');
  print('');
  print('Opciones (si se ejecuta con args):');
  print('  --apply              Aplica cambios (por defecto es dry-run)');
  print('  --tenant=<id>        Filtra por tenant_id');
  print(
      '  --limit=<n>          Máximo de documentos a escanear (0 = sin límite)');
  print('  --page-size=<n>      Tamaño de página de lectura (default: 200)');
  print('  --help               Muestra esta ayuda');
}

int _readIntArg(List<String> args, String key, int defaultValue) {
  final prefix = '$key=';
  final raw = args.firstWhere(
    (a) => a.startsWith(prefix),
    orElse: () => '',
  );
  if (raw.isEmpty) return defaultValue;
  final value = int.tryParse(raw.substring(prefix.length));
  return value ?? defaultValue;
}

String? _readStringArg(List<String> args, String key) {
  final prefix = '$key=';
  final raw = args.firstWhere(
    (a) => a.startsWith(prefix),
    orElse: () => '',
  );
  if (raw.isEmpty) return null;
  final value = raw.substring(prefix.length).trim();
  return value.isEmpty ? null : value;
}

int _readIntDefineOrArg(
  List<String> args,
  String argKey,
  String defineValue,
  int defaultValue,
) {
  final fromArg = _readIntArg(args, argKey, defaultValue);
  if (fromArg != defaultValue) return fromArg;
  final value = int.tryParse(defineValue.trim());
  return value ?? defaultValue;
}

String? _readStringDefineOrArg(
  List<String> args,
  String argKey,
  String defineValue,
) {
  final fromArg = _readStringArg(args, argKey);
  if (fromArg != null) return fromArg;
  final value = defineValue.trim();
  return value.isEmpty ? null : value;
}

bool _readBoolDefineOrArg(
  List<String> args,
  String argFlag,
  String defineValue,
) {
  if (args.contains(argFlag)) return true;
  final raw = defineValue.trim().toLowerCase();
  return raw == '1' || raw == 'true' || raw == 'yes';
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  const applyDefine = String.fromEnvironment('BACKFILL_APPLY');
  const tenantDefine = String.fromEnvironment('BACKFILL_TENANT');
  const limitDefine = String.fromEnvironment('BACKFILL_LIMIT');
  const pageSizeDefine = String.fromEnvironment('BACKFILL_PAGE_SIZE');

  if (args.contains('--help')) {
    _printUsage();
    return;
  }

  final apply = _readBoolDefineOrArg(args, '--apply', applyDefine);
  final tenantId = _readStringDefineOrArg(args, '--tenant', tenantDefine);
  final limit = _readIntDefineOrArg(args, '--limit', limitDefine, 0);
  final pageSize = _readIntDefineOrArg(args, '--page-size', pageSizeDefine, 200)
      .clamp(1, 500);

  print(apply
      ? 'Modo APPLY: se escribirán cambios en Firestore.'
      : 'Modo DRY-RUN: no se escribirá ningún cambio.');
  if (tenantId != null) print('Filtro tenant_id: $tenantId');
  if (limit > 0) print('Límite de escaneo: $limit');
  print('Page size: $pageSize');
  print('');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseId,
  );

  int scanned = 0;
  int missingUsername = 0;
  int updatable = 0;
  int updated = 0;
  int unchanged = 0;
  int sampled = 0;

  DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  while (true) {
    Query<Map<String, dynamic>> query =
        db.collection('usuarios').orderBy(FieldPath.documentId).limit(pageSize);

    if (tenantId != null) {
      query = query.where('tenant_id', isEqualTo: tenantId);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snap = await query.get();
    if (snap.docs.isEmpty) break;

    final batch = db.batch();

    for (final doc in snap.docs) {
      if (limit > 0 && scanned >= limit) break;

      scanned += 1;
      final data = doc.data();

      final fromLogin = (data['login_username'] ?? '').toString().trim();
      final fromNombre = (data['nombre_usuario'] ?? '').toString().trim();
      final canonical = fromLogin.isNotEmpty ? fromLogin : fromNombre;

      if (canonical.isEmpty) {
        missingUsername += 1;
        continue;
      }

      final normalized = canonical.toLowerCase();
      final currentLogin = (data['login_username'] ?? '').toString().trim();
      final currentLc = (data['nombre_usuario_lc'] ?? '').toString().trim();

      final needsUpdate = currentLogin != canonical || currentLc != normalized;

      if (!needsUpdate) {
        unchanged += 1;
        continue;
      }

      updatable += 1;

      if (!apply && sampled < 20) {
        print(
          '[sample] doc=${doc.id} login_username: "$currentLogin" -> "$canonical" | '
          'nombre_usuario_lc: "$currentLc" -> "$normalized"',
        );
        sampled += 1;
      }

      if (apply) {
        batch.update(doc.reference, {
          'login_username': canonical,
          'nombre_usuario_lc': normalized,
        });
        updated += 1;
      }
    }

    if (apply && updated > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs.last;

    if (limit > 0 && scanned >= limit) break;
  }

  print('');
  print('Resumen:');
  print('  Escaneados: $scanned');
  print('  Sin nombre de usuario: $missingUsername');
  print('  Ya consistentes: $unchanged');
  print('  Candidatos a actualizar: $updatable');
  print('  Actualizados: $updated');
  print(apply
      ? 'Backfill aplicado correctamente.'
      : 'Dry-run completado. Usa --apply para ejecutar cambios.');
}
