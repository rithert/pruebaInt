import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_apps/mini_apps.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements MiniAppsRepository {}

void main() {
  late _MockRepository repository;
  final token = DelegatedToken(
    token: 'delegado',
    expiresAt: DateTime(2026, 10, 4, 12, 5),
  );

  setUp(() => repository = _MockRepository());

  MiniAppCubit build() => MiniAppCubit(
    repository: repository,
    appId: 'credit-simulator',
    telemetry: const DebugTelemetry(),
  );

  void stubToken(Result<DelegatedToken> result) =>
      when(() => repository.issueToken('credit-simulator'))
          .thenAnswer((_) async => result);

  blocTest<MiniAppCubit, MiniAppState>(
    'autoriza con un token delegado',
    setUp: () => stubToken(Success(token)),
    build: build,
    act: (cubit) => cubit.authorize(),
    expect: () => [
      const MiniAppState(),
      MiniAppState(status: MiniAppStatus.ready, token: token),
    ],
  );

  blocTest<MiniAppCubit, MiniAppState>(
    'KILL SWITCH: si el servidor la desactivó, no se carga',
    setUp: () => stubToken(
      const Failure(
        BusinessFailure(code: 'mini_app_disabled', serverMessage: 'x'),
      ),
    ),
    build: build,
    act: (cubit) => cubit.authorize(),
    skip: 1,
    expect: () => [const MiniAppState(status: MiniAppStatus.unavailable)],
  );

  blocTest<MiniAppCubit, MiniAppState>(
    'sin red: falla con opción de reintentar',
    setUp: () => stubToken(const Failure(NoConnectionFailure())),
    build: build,
    act: (cubit) => cubit.authorize(),
    skip: 1,
    expect: () => [
      const MiniAppState(
        status: MiniAppStatus.failure,
        failure: NoConnectionFailure(),
      ),
    ],
  );

  blocTest<MiniAppCubit, MiniAppState>(
    'renovar el token no vuelve a "conectando" (la mini app sigue visible)',
    setUp: () => stubToken(Success(token)),
    build: build,
    seed: () => MiniAppState(status: MiniAppStatus.ready, token: token),
    act: (cubit) => cubit.authorize(),
    expect: () => <MiniAppState>[],
  );

  test('la solicitud de crédito la ejecuta el repositorio de la app', () async {
    when(() => repository.requestCredit(amountMinor: 500000, termMonths: 24))
        .thenAnswer((_) async => const Success('app-123'));

    final result = await build().requestCredit(
      amountMinor: 500000,
      termMonths: 24,
    );

    expect(result, const Success('app-123'));
  });
}
