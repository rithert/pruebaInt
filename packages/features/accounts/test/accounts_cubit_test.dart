import 'dart:async';

import 'package:accounts/accounts.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AccountsRepository {}

class _FakeConnectivity implements ConnectivityMonitor {
  // Se cierra en tearDown.
  // ignore: close_sinks
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => controller.stream;
}

const _overview = AccountsOverview(accounts: [], totalMinor: 100);

void main() {
  late _MockRepository repository;
  late _FakeConnectivity connectivity;

  setUp(() {
    repository = _MockRepository();
    connectivity = _FakeConnectivity();
  });
  tearDown(() => connectivity.controller.close());

  AccountsCubit build() =>
      AccountsCubit(repository: repository, connectivity: connectivity);

  test('emite lo que entrega el stale-while-revalidate', () async {
    when(() => repository.watchOverview()).thenAnswer(
      (_) => Stream.fromIterable([
        const Resource(isRefreshing: true),
        const Resource(data: _overview),
      ]),
    );
    final cubit = build();

    await cubit.refresh();

    expect(cubit.state.data, _overview);
    expect(cubit.state.isRefreshing, isFalse);
    await cubit.close();
  });

  test('al reintentar no vuelve al skeleton si ya mostraba datos', () async {
    when(() => repository.watchOverview()).thenAnswer(
      (_) => Stream.fromIterable([
        const Resource(data: _overview, failure: NoConnectionFailure()),
      ]),
    );
    final cubit = build();
    await cubit.refresh();

    when(() => repository.watchOverview()).thenAnswer(
      (_) => Stream.fromIterable([const Resource(isRefreshing: true)]),
    );
    final states = <Resource<AccountsOverview>>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.refresh();

    expect(states.single.data, _overview);
    expect(states.single.isRefreshing, isTrue);
    await sub.cancel();
    await cubit.close();
  });

  test('se actualiza solo al recuperar la conexión tras una falla', () async {
    when(() => repository.watchOverview()).thenAnswer(
      (_) => Stream.fromIterable([
        const Resource(data: _overview, failure: NoConnectionFailure()),
      ]),
    );
    final cubit = build();
    await cubit.refresh();
    clearInteractions(repository);

    connectivity.controller.add(true);
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.watchOverview()).called(1);
    await cubit.close();
  });
}
