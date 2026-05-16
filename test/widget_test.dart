// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventario_app/app.dart';
import 'package:inventario_app/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('InventarioApp smoke test - renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const InventarioApp(),
      ),
    );
    await tester.pump();
    // Verifica que la app arranca sin lanzar excepciones
    expect(tester.takeException(), isNull);
  });
}
