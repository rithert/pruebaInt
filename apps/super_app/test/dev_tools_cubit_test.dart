import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_app/diagnostics/dev_tools_cubit.dart';

void main() {
  late FakeAdapter adapter;
  late DevToolsCubit cubit;

  const chaosOff = {'enabled': false, 'services': <String, Object?>{}};
  const flags = {'insights': true, 'promotions': true, 'miniApps': true};

  setUp(() {
    adapter = FakeAdapter();
    cubit = DevToolsCubit(
      api: ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      ),
      adminKey: 'clave-admin',
      customerEmail: () => 'ana@example.com',
    );
  });
  tearDown(() => cubit.close());

  test('carga chaos y flags con la clave de administración', () async {
    adapter
      ..enqueueJson(200, chaosOff)
      ..enqueueJson(200, flags);

    await cubit.load();

    expect(cubit.state.loading, isFalse);
    expect(cubit.state.flags, {
      'insights': true,
      'promotions': true,
      'miniApps': true,
    });
    expect(
      adapter.requests.every((r) => r.headers['x-admin-key'] == 'clave-admin'),
      isTrue,
    );
  });

  test('caer un servicio envía la falla y refleja el estado', () async {
    adapter.enqueueJson(200, {
      'enabled': true,
      'services': {
        'accounts': {'latencyMs': 0, 'errorRate': 0, 'down': true},
      },
    });

    await cubit.toggleFault('accounts', FaultKind.down, true);

    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.data, {
      'enabled': true,
      'services': {
        'accounts': {'down': true},
      },
    });
    expect(cubit.state.isOn('accounts', FaultKind.down), isTrue);
    expect(cubit.state.isOn('accounts', FaultKind.slow), isFalse);
  });

  test('latencia y errores usan valores de demo (3 s, 50%)', () async {
    adapter
      ..enqueueJson(200, chaosOff)
      ..enqueueJson(200, chaosOff);

    await cubit.toggleFault('experience', FaultKind.slow, true);
    await cubit.toggleFault('experience', FaultKind.errors, true);

    expect((adapter.requests[0].data as Map)['services'], {
      'experience': {'latencyMs': 3000},
    });
    expect((adapter.requests[1].data as Map)['services'], {
      'experience': {'errorRate': 0.5},
    });
  });

  test('generar movimiento usa el correo del cliente', () async {
    adapter.enqueueJson(200, {'created': <Object>[]});

    await cubit.generateMovement();

    expect(adapter.requests.single.path, '/admin/activity/tick');
    expect(adapter.requests.single.data, {'email': 'ana@example.com'});
    expect(cubit.state.message, contains('notificación'));
  });

  test('si el servidor rechaza la acción, se informa sin romper', () async {
    adapter.enqueueError(403, 'forbidden');

    await cubit.setFlag('promotions', false);

    expect(cubit.state.message, isNotNull);
  });
}
