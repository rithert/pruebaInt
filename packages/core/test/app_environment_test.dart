import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment', () {
    test('usa valores de desarrollo cuando no hay --dart-define', () {
      final env = AppEnvironment.fromDefines();

      expect(env.name, 'dev');
      expect(env.apiBaseUrl, 'http://10.0.2.2:3000');
      expect(env.isProduction, isFalse);
    });

    test('isProduction solo es verdadero para prod', () {
      const env = AppEnvironment(
        name: 'prod',
        apiBaseUrl: 'https://api.example.com',
        enableDebugTools: false,
      );

      expect(env.isProduction, isTrue);
    });
  });
}
