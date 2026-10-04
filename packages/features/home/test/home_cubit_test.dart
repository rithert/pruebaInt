import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/home.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sdui/sdui.dart';

class _MockRepository extends Mock implements HomeRepository {}

class _MockTracker extends Mock implements EventTracker {}

class _NoConnectivity implements ConnectivityMonitor {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => const Stream.empty();
}

const _layout = SduiLayout(
  schemaVersion: 1,
  layoutId: 'home.saver',
  components: [
    SduiComponent(id: 'greeting', type: 'greeting'),
    SduiComponent(id: 'promo.saver', type: 'promo_banner'),
  ],
);

void main() {
  late _MockRepository repository;
  late _MockTracker tracker;

  setUp(() {
    repository = _MockRepository();
    tracker = _MockTracker();
    when(() => tracker.flush()).thenAnswer((_) async {});
  });

  HomeCubit build() => HomeCubit(
    repository: repository,
    tracker: tracker,
    connectivity: _NoConnectivity(),
  );

  test('muestra el layout del servidor', () async {
    when(() => repository.watchHome())
        .thenAnswer((_) => Stream.value(const Resource(data: _layout)));
    final cubit = build();

    await cubit.refresh();

    expect(cubit.state.layout?.components.map((c) => c.id), [
      'greeting',
      'promo.saver',
    ]);
    expect(cubit.state.isFallback, isFalse);
    await cubit.close();
  });

  test('servicio caído y sin caché: usa el layout embebido', () async {
    when(() => repository.watchHome()).thenAnswer(
      (_) => Stream.value(const Resource(failure: ServiceUnavailableFailure())),
    );
    final cubit = build();

    await cubit.refresh();

    expect(cubit.state.isFallback, isTrue);
    expect(
      cubit.state.layout?.components.map((c) => c.type),
      contains('accounts_summary'),
      reason: 'el cliente siempre puede ver sus cuentas',
    );
    await cubit.close();
  });

  test('descartar oculta al instante y registra el evento', () async {
    when(() => repository.watchHome())
        .thenAnswer((_) => Stream.value(const Resource(data: _layout)));
    final cubit = build();
    await cubit.refresh();

    cubit.dismiss('promo.saver');

    expect(cubit.state.layout?.components.map((c) => c.id), ['greeting']);
    verify(() => tracker.track('dismissed', 'promo.saver')).called(1);
    await cubit.close();
  });

  test('al cerrar envía los eventos pendientes', () async {
    when(() => repository.watchHome()).thenAnswer((_) => const Stream.empty());
    final cubit = build();

    await cubit.close();
    await Future<void>.delayed(Duration.zero);

    verify(() => tracker.flush()).called(1);
  });
}
