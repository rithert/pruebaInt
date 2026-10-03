import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_app/app.dart';

void main() {
  testWidgets('la app arranca y muestra el entorno configurado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SuperApp(
        environment: AppEnvironment(
          name: 'test',
          apiBaseUrl: 'http://localhost',
          enableDebugTools: false,
        ),
      ),
    );

    expect(find.text('Entorno: test'), findsOneWidget);
  });
}
