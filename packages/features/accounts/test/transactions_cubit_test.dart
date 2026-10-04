import 'dart:async';

import 'package:accounts/accounts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Especificación del TransactionsCubit: paginación por cursor, filtro por
/// categoría, refresh y manejo de errores sin perder lo ya cargado.

class _MockRepository extends Mock implements AccountsRepository {}

Transaction _tx(String id) => Transaction(
  id: id,
  accountId: 'acc-1',
  amountMinor: -1000,
  balanceAfterMinor: 0,
  currency: 'USD',
  description: 'Compra',
  category: 'groceries',
  bookedAt: DateTime(2026, 10, 3),
);

final _page1 = TransactionPage(items: [_tx('1'), _tx('2')], nextCursor: 'c2');
final _page2 = TransactionPage(items: [_tx('3')], nextCursor: null);
final _cachedAt = DateTime(2026, 10, 3, 9);

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  TransactionsCubit build() =>
      TransactionsCubit(repository: repository, accountId: 'acc-1');

  void stubPage(
    Result<TransactionPage> result, {
    String? cursor,
    String? category,
  }) => when(
    () => repository.transactions('acc-1', cursor: cursor, category: category),
  ).thenAnswer((_) async => result);

  test('arranca en initial sin items', () {
    expect(build().state, const TransactionsState());
  });

  group('load (primera página)', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'éxito: loading → success con items y cursor',
      setUp: () => stubPage(Success(_page1)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const TransactionsState(status: TransactionsStatus.loading),
        TransactionsState(
          status: TransactionsStatus.success,
          items: _page1.items,
          nextCursor: 'c2',
        ),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'falla sin caché: loading → failure',
      setUp: () => stubPage(const Failure(NoConnectionFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const TransactionsState(status: TransactionsStatus.loading),
        const TransactionsState(
          status: TransactionsStatus.failure,
          failure: NoConnectionFailure(),
        ),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'página de caché: success con cachedAt (la UI muestra el banner)',
      setUp: () => stubPage(
        Success(
          TransactionPage(
            items: _page1.items,
            nextCursor: null,
            cachedAt: _cachedAt,
          ),
        ),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        TransactionsState(
          status: TransactionsStatus.success,
          items: _page1.items,
          cachedAt: _cachedAt,
        ),
      ],
      verify: (cubit) => expect(cubit.state.isStale, isTrue),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'un load exitoso limpia el error y la marca de caché anteriores',
      setUp: () => stubPage(Success(_page1)),
      build: build,
      seed: () => TransactionsState(
        status: TransactionsStatus.failure,
        failure: const NoConnectionFailure(),
        cachedAt: _cachedAt,
      ),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        TransactionsState(
          status: TransactionsStatus.success,
          items: _page1.items,
          nextCursor: 'c2',
        ),
      ],
    );
  });

  group('loadMore (paginación)', () {
    final loaded = TransactionsState(
      status: TransactionsStatus.success,
      items: _page1.items,
      nextCursor: 'c2',
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'agrega la siguiente página usando el cursor',
      setUp: () => stubPage(Success(_page2), cursor: 'c2'),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.loadMore(),
      expect: () => [
        loaded.copyWith(isLoadingMore: true),
        loaded.copyWith(
          items: [..._page1.items, ..._page2.items],
          nextCursor: () => null,
        ),
      ],
      verify: (cubit) => expect(cubit.state.hasReachedEnd, isTrue),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'no pide nada si ya llegó al final',
      build: build,
      seed: () => loaded.copyWith(nextCursor: () => null),
      act: (cubit) => cubit.loadMore(),
      expect: () => <TransactionsState>[],
      verify: (_) => verifyNever(
        () => repository.transactions(
          any(),
          cursor: any(named: 'cursor'),
          category: any(named: 'category'),
        ),
      ),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'no pide nada si la primera página no cargó',
      build: build,
      seed: () => const TransactionsState(status: TransactionsStatus.loading),
      act: (cubit) => cubit.loadMore(),
      expect: () => <TransactionsState>[],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'ignora llamadas repetidas mientras carga (el scroll dispara varias)',
      setUp: () => stubPage(Success(_page2), cursor: 'c2'),
      build: build,
      seed: () => loaded,
      act: (cubit) async {
        final first = cubit.loadMore();
        await cubit.loadMore();
        await cubit.loadMore();
        await first;
      },
      verify: (_) => verify(
        () => repository.transactions('acc-1', cursor: 'c2', category: null),
      ).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'si falla, conserva los items y expone loadMoreFailure',
      setUp: () => stubPage(const Failure(TimeoutFailure()), cursor: 'c2'),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.loadMore(),
      expect: () => [
        loaded.copyWith(isLoadingMore: true),
        loaded.copyWith(loadMoreFailure: () => const TimeoutFailure()),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'reintentar loadMore limpia el error anterior',
      setUp: () => stubPage(Success(_page2), cursor: 'c2'),
      build: build,
      seed: () =>
          loaded.copyWith(loadMoreFailure: () => const TimeoutFailure()),
      act: (cubit) => cubit.loadMore(),
      expect: () => [
        loaded.copyWith(isLoadingMore: true),
        loaded.copyWith(
          items: [..._page1.items, ..._page2.items],
          nextCursor: () => null,
        ),
      ],
    );
  });

  group('refresh (pull-to-refresh)', () {
    final loaded = TransactionsState(
      status: TransactionsStatus.success,
      items: [..._page1.items, ..._page2.items],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'reemplaza los items por la primera página SIN pasar por loading',
      setUp: () => stubPage(Success(_page1)),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.refresh(),
      expect: () => [
        TransactionsState(
          status: TransactionsStatus.success,
          items: _page1.items,
          nextCursor: 'c2',
        ),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'si falla, conserva lo que se ve y expone la falla',
      setUp: () => stubPage(const Failure(ServiceUnavailableFailure())),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.refresh(),
      expect: () => [
        loaded.copyWith(failure: () => const ServiceUnavailableFailure()),
      ],
    );
  });

  group('filtro por categoría', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'cambia el filtro, vacía la lista y carga con la categoría',
      setUp: () => stubPage(Success(_page2), category: 'income'),
      build: build,
      seed: () => TransactionsState(
        status: TransactionsStatus.success,
        items: _page1.items,
        nextCursor: 'c2',
      ),
      act: (cubit) => cubit.categorySelected('income'),
      expect: () => [
        const TransactionsState(
          status: TransactionsStatus.loading,
          category: 'income',
        ),
        TransactionsState(
          status: TransactionsStatus.success,
          items: _page2.items,
          category: 'income',
        ),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'elegir el mismo filtro no hace nada',
      build: build,
      seed: () => const TransactionsState(
        status: TransactionsStatus.success,
        category: 'income',
      ),
      act: (cubit) => cubit.categorySelected('income'),
      expect: () => <TransactionsState>[],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'descarta una respuesta vieja si el filtro cambió mientras cargaba',
      setUp: () {
        final slowAll = Completer<Result<TransactionPage>>();
        when(
          () => repository.transactions('acc-1', cursor: null, category: null),
        ).thenAnswer((_) => slowAll.future);
        stubPage(Success(_page2), category: 'income');
        // La respuesta "todas" llega DESPUÉS de la de "income".
        Future<void>.delayed(
          const Duration(milliseconds: 30),
          () => slowAll.complete(Success(_page1)),
        );
      },
      build: build,
      act: (cubit) async {
        unawaited(cubit.load());
        await cubit.categorySelected('income');
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (cubit) {
        expect(cubit.state.category, 'income');
        expect(cubit.state.items, _page2.items);
      },
    );
  });
}
