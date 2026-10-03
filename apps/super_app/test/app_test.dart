import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_app/diagnostics/diagnostics_cubit.dart';
import 'package:super_app/diagnostics/diagnostics_page.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _FakeConnectivity implements ConnectivityMonitor {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => const Stream.empty();
}

void main() {
  const environment = AppEnvironment(
    name: 'test',
    apiBaseUrl: 'http://localhost',
    enableDebugTools: true,
  );

  late _MockApiClient api;

  setUp(() => api = _MockApiClient());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => DiagnosticsCubit(
            api: api,
            connectivity: _FakeConnectivity(),
            circuitBreaker: CircuitBreaker(),
          )..start(),
          child: const DiagnosticsPage(environment: environment),
        ),
      ),
    );
    await tester.pump();
  }

  void stubHealth(Result<Object?> result) {
    when(() => api.get<Object?>('/health', decode: any(named: 'decode')))
        .thenAnswer((_) async => result);
  }

  testWidgets('muestra el entorno y la conectividad', (tester) async {
    await pumpPage(tester);

    expect(find.text('test · http://localhost'), findsOneWidget);
    expect(find.text('Conectado a una red'), findsOneWidget);
  });

  testWidgets('prueba la conexión y muestra la latencia', (tester) async {
    stubHealth(const Success({'status': 'ok'}));
    await pumpPage(tester);

    await tester.tap(find.text('Probar conexión con el servidor'));
    await tester.pump();

    expect(find.textContaining('Servidor disponible'), findsOneWidget);
  });

  testWidgets('ante una falla muestra el mensaje y el código de soporte', (
    tester,
  ) async {
    stubHealth(
      const Failure(ServiceUnavailableFailure(correlationId: 'corr-42')),
    );
    await pumpPage(tester);

    await tester.tap(find.text('Probar conexión con el servidor'));
    await tester.pump();

    expect(
      find.textContaining('Este servicio no está disponible'),
      findsOneWidget,
    );
    expect(find.textContaining('Código de soporte: corr-42'), findsOneWidget);
  });

  testWidgets('cumple las guías de accesibilidad de Flutter', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
