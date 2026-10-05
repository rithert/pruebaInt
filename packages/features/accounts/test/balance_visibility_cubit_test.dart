import 'dart:async';

import 'package:accounts/accounts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacenamiento que falla al leer o escribir (disco lleno, base corrupta).
class _BrokenStore implements CacheStore {
  _BrokenStore({this.failRead = false, this.failWrite = false});

  final bool failRead;
  final bool failWrite;

  @override
  Future<CacheEntry?> read(String key) async =>
      failRead ? throw StateError('disco') : null;

  @override
  Future<void> write(String key, Object? json, {DateTime? updatedAt}) async {
    if (failWrite) throw StateError('disco');
  }

  @override
  Future<void> clear() async {}
}

/// Almacenamiento cuya lectura no termina hasta que el test lo decide. Lee
/// el valor al EMPEZAR: así entrega el dato viejo aunque se escriba otro
/// mientras tanto (lo que pasa con una consulta lenta a la base).
class _SlowStore extends InMemoryCacheStore {
  final reading = Completer<void>();

  @override
  Future<CacheEntry?> read(String key) async {
    final snapshot = await super.read(key);
    await reading.future;
    return snapshot;
  }
}

void main() {
  const key = BalanceVisibilityCubit.storageKey;
  late InMemoryCacheStore store;

  setUp(() => store = InMemoryCacheStore());

  BalanceVisibilityCubit build() => BalanceVisibilityCubit(store: store);

  test('por defecto los saldos se muestran', () {
    expect(build().state, isFalse);
  });

  group('load', () {
    blocTest<BalanceVisibilityCubit, bool>(
      'sin preferencia guardada no emite nada',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => <bool>[],
    );

    blocTest<BalanceVisibilityCubit, bool>(
      'recupera "ocultos" de una sesión anterior',
      setUp: () => store.write(key, true),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [true],
    );

    blocTest<BalanceVisibilityCubit, bool>(
      'un valor guardado que no es bool se ignora (no rompe la app)',
      setUp: () => store.write(key, 'sí'),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => <bool>[],
    );

    test(
      'CARRERA: una lectura lenta no deshace lo que el usuario tocó',
      () async {
        final slow = _SlowStore();
        await slow.write(key, false);
        final cubit = BalanceVisibilityCubit(store: slow);

        final loading = cubit.load(); // la lectura queda pendiente
        await cubit.toggle(); // el usuario oculta mientras tanto
        slow.reading.complete(); // llega el valor viejo (visible)
        await loading;

        expect(cubit.state, isTrue);
        await cubit.close();
      },
    );

    blocTest<BalanceVisibilityCubit, bool>(
      'si el almacenamiento falla al leer, se queda visible',
      build: () => BalanceVisibilityCubit(store: _BrokenStore(failRead: true)),
      act: (cubit) => cubit.load(),
      expect: () => <bool>[],
    );
  });

  group('toggle', () {
    blocTest<BalanceVisibilityCubit, bool>(
      'oculta y guarda la elección',
      build: build,
      act: (cubit) => cubit.toggle(),
      expect: () => [true],
      verify: (_) async => expect((await store.read(key))?.json, isTrue),
    );

    blocTest<BalanceVisibilityCubit, bool>(
      'dos toques vuelven a mostrar y lo guardan',
      build: build,
      act: (cubit) async {
        await cubit.toggle();
        await cubit.toggle();
      },
      expect: () => [true, false],
      verify: (_) async => expect((await store.read(key))?.json, isFalse),
    );

    blocTest<BalanceVisibilityCubit, bool>(
      'si no se puede guardar, igual respeta lo que pidió el usuario',
      build: () => BalanceVisibilityCubit(store: _BrokenStore(failWrite: true)),
      act: (cubit) => cubit.toggle(),
      expect: () => [true],
    );

    blocTest<BalanceVisibilityCubit, bool>(
      'el cambio se ve ANTES de terminar de guardar (sin esperar al disco)',
      build: build,
      act: (cubit) {
        // Sin await: el estado debe cambiar de forma síncrona.
        cubit.toggle();
        expect(cubit.state, isTrue);
      },
      expect: () => [true],
    );
  });
}
