import 'dart:async';

import 'package:accounts/accounts.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AccountsRepository {}

class _StreamConnectivity implements ConnectivityMonitor {
  _StreamConnectivity(this.onStatusChange);

  @override
  final Stream<bool> onStatusChange;

  @override
  Future<bool> get isOnline async => true;
}

const _main = Account(
  id: 'main',
  type: AccountType.savings,
  name: 'Ahorros',
  maskedNumber: '•••• 1',
  currency: 'USD',
  balanceMinor: 10000000, // $ 100.000
);
const _goal = Account(
  id: 'goal',
  type: AccountType.savings,
  name: 'Metas',
  maskedNumber: '•••• 2',
  currency: 'USD',
  balanceMinor: 0,
);
const _receipt = TransferReceipt(
  transferId: 'tr-1',
  amountMinor: 5000000,
  currency: 'USD',
  fromBalanceMinor: 5000000,
  toBalanceMinor: 5000000,
);

void main() {
  late _MockRepository repository;
  late int keys;

  setUp(() {
    repository = _MockRepository();
    keys = 0;
    when(() => repository.watchOverview()).thenAnswer(
      (_) => Stream.value(
        const Resource(
          data: AccountsOverview(accounts: [_main, _goal], totalMinor: 0),
        ),
      ),
    );
  });

  TransferCubit build() =>
      TransferCubit(repository: repository, newKey: () => 'key-${++keys}');

  void stubTransfer(Result<TransferReceipt> result) => when(
    () => repository.transfer(
      fromAccountId: any(named: 'fromAccountId'),
      toAccountId: any(named: 'toAccountId'),
      amountMinor: any(named: 'amountMinor'),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer((_) async => result);

  String sentKey() =>
      verify(
            () => repository.transfer(
              fromAccountId: any(named: 'fromAccountId'),
              toAccountId: any(named: 'toAccountId'),
              amountMinor: any(named: 'amountMinor'),
              idempotencyKey: captureAny(named: 'idempotencyKey'),
            ),
          ).captured.last
          as String;

  test('start carga las cuentas y preselecciona origen y destino', () async {
    final cubit = build();
    await cubit.start();

    expect(cubit.state.status, TransferStatus.editing);
    expect(cubit.state.fromId, 'main');
    expect(cubit.state.toId, 'goal');
  });

  blocTest<TransferCubit, TransferState>(
    'valida el monto contra el saldo antes de llamar al BFF',
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.amountChanged('200000');
      await cubit.submit();
    },
    verify: (cubit) {
      expect(cubit.state.fieldErrors[TransferField.amount], contains('Supera'));
      verifyNever(
        () => repository.transfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountMinor: any(named: 'amountMinor'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    },
  );

  blocTest<TransferCubit, TransferState>(
    'éxito: envía el monto en centavos y guarda el comprobante',
    setUp: () => stubTransfer(const Success(_receipt)),
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.amountChanged('50000');
      await cubit.submit();
    },
    verify: (cubit) {
      expect(cubit.state.status, TransferStatus.success);
      expect(cubit.state.receipt, _receipt);
      verify(
        () => repository.transfer(
          fromAccountId: 'main',
          toAccountId: 'goal',
          amountMinor: 5000000,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  blocTest<TransferCubit, TransferState>(
    'IDEMPOTENCIA: reintentar tras una falla reutiliza la MISMA clave',
    setUp: () => stubTransfer(const Failure(TimeoutFailure())),
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.amountChanged('50000');
      await cubit.submit();
      await cubit.submit();
    },
    verify: (cubit) {
      final captured = verify(
        () => repository.transfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountMinor: any(named: 'amountMinor'),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;
      expect(captured, hasLength(2));
      expect(captured.toSet(), hasLength(1));
    },
  );

  blocTest<TransferCubit, TransferState>(
    'cambiar un dato tras una falla genera una clave NUEVA',
    setUp: () => stubTransfer(const Failure(TimeoutFailure())),
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.amountChanged('50000');
      await cubit.submit();
      final firstKey = sentKey();
      cubit.amountChanged('40000');
      await cubit.submit();
      expect(sentKey(), isNot(firstKey));
    },
  );

  blocTest<TransferCubit, TransferState>(
    'saldo insuficiente del BFF se muestra en el campo monto',
    setUp: () => stubTransfer(
      const Failure(
        BusinessFailure(code: 'insufficient_funds', serverMessage: 'x'),
      ),
    ),
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.amountChanged('1000');
      await cubit.submit();
    },
    verify: (cubit) => expect(
      cubit.state.fieldErrors[TransferField.amount],
      'Saldo insuficiente.',
    ),
  );

  test('al volver la red tras un fallo, invita a reintentar SIN reintentar '
      'solo', () async {
    stubTransfer(const Failure(NoConnectionFailure()));
    final network = StreamController<bool>();
    final cubit = TransferCubit(
      repository: repository,
      connectivity: _StreamConnectivity(network.stream),
      newKey: () => 'key-${++keys}',
    );
    await cubit.start();
    cubit.amountChanged('1000');
    await cubit.submit();

    network.add(true);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.connectionRestored, isTrue);
    expect(cubit.state.status, TransferStatus.failure);
    verify(
      () => repository.transfer(
        fromAccountId: any(named: 'fromAccountId'),
        toAccountId: any(named: 'toAccountId'),
        amountMinor: any(named: 'amountMinor'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
    await network.close();
    await cubit.close();
  });

  blocTest<TransferCubit, TransferState>(
    'no permite la misma cuenta en origen y destino',
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit
        ..toSelected('main')
        ..amountChanged('1000');
      await cubit.submit();
    },
    verify: (cubit) =>
        expect(cubit.state.fieldErrors[TransferField.to], isNotNull),
  );
}
