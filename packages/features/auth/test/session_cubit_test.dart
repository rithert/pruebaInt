import 'package:auth/auth.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockBiometrics extends Mock implements BiometricAuthenticator {}

class _SilentTelemetry implements Telemetry {
  @override
  void breadcrumb(String message, {Map<String, Object?> data = const {}}) {}

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {}

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void setUserId(String? userId) {}
}

const _user = UserProfile(
  id: 'u1',
  email: 'ana@example.com',
  fullName: 'Ana Gómez',
  goal: FinancialGoal.save,
  segment: 'saver',
);

void main() {
  late _MockAuthRepository repository;
  late _MockBiometrics biometrics;
  late SessionEvents events;

  setUp(() {
    repository = _MockAuthRepository();
    biometrics = _MockBiometrics();
    events = SessionEvents();
    when(() => repository.logout()).thenAnswer((_) async {});
    when(() => repository.fetchProfile())
        .thenAnswer((_) async => const Success(_user));
    when(() => repository.cachedProfile()).thenAnswer((_) async => _user);
  });

  SessionCubit build() => SessionCubit(
    repository: repository,
    biometrics: biometrics,
    telemetry: _SilentTelemetry(),
    sessionEvents: events,
  );

  void storedSession(bool value) =>
      when(() => repository.hasStoredSession()).thenAnswer((_) async => value);

  void biometricsAvailable(bool value) =>
      when(() => biometrics.isAvailable()).thenAnswer((_) async => value);

  group('restore', () {
    blocTest<SessionCubit, SessionState>(
      'sin sesión guardada → unauthenticated',
      setUp: () => storedSession(false),
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionState(status: SessionStatus.unauthenticated)],
    );

    blocTest<SessionCubit, SessionState>(
      'con sesión y biometría → locked con el perfil en caché',
      setUp: () {
        storedSession(true);
        biometricsAvailable(true);
      },
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [
        const SessionState(status: SessionStatus.locked, user: _user),
      ],
    );

    blocTest<SessionCubit, SessionState>(
      'con sesión sin biometría → authenticated directo',
      setUp: () {
        storedSession(true);
        biometricsAvailable(false);
      },
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [
        const SessionState(status: SessionStatus.authenticated, user: _user),
      ],
    );
  });

  group('desbloqueo', () {
    blocTest<SessionCubit, SessionState>(
      'huella correcta → authenticated',
      setUp: () =>
          when(() => biometrics.authenticate(reason: any(named: 'reason')))
              .thenAnswer((_) async => true),
      build: build,
      seed: () => const SessionState(status: SessionStatus.locked, user: _user),
      act: (cubit) => cubit.unlock(),
      expect: () => [
        const SessionState(status: SessionStatus.authenticated, user: _user),
      ],
    );

    blocTest<SessionCubit, SessionState>(
      'huella cancelada → sigue bloqueada',
      setUp: () =>
          when(() => biometrics.authenticate(reason: any(named: 'reason')))
              .thenAnswer((_) async => false),
      build: build,
      seed: () => const SessionState(status: SessionStatus.locked, user: _user),
      act: (cubit) => cubit.unlock(),
      expect: () => <SessionState>[],
    );

    blocTest<SessionCubit, SessionState>(
      'usar contraseña cierra la sesión local y va al login',
      build: build,
      seed: () => const SessionState(status: SessionStatus.locked, user: _user),
      act: (cubit) => cubit.usePassword(),
      expect: () => [const SessionState(status: SessionStatus.unauthenticated)],
      verify: (_) => verify(() => repository.logout()).called(1),
    );
  });

  blocTest<SessionCubit, SessionState>(
    'signedIn → authenticated con el usuario',
    build: build,
    seed: () => const SessionState(status: SessionStatus.unauthenticated),
    act: (cubit) => cubit.signedIn(_user),
    expect: () => [
      const SessionState(status: SessionStatus.authenticated, user: _user),
    ],
  );

  blocTest<SessionCubit, SessionState>(
    'logout borra datos y deja el motivo',
    build: build,
    seed: () =>
        const SessionState(status: SessionStatus.authenticated, user: _user),
    act: (cubit) => cubit.logout(),
    expect: () => [
      const SessionState(
        status: SessionStatus.unauthenticated,
        endReason: SessionEndReason.logout,
      ),
    ],
  );

  test('los hooks de cierre corren ANTES de borrar las credenciales', () async {
    final order = <String>[];
    when(() => repository.logout())
        .thenAnswer((_) async => order.add('logout'));
    final cubit = build()
      ..addBeforeEndHook(() async => order.add('baja push'))
      ..addBeforeEndHook(() async => throw StateError('sin red'));

    await cubit.logout();

    expect(order, ['baja push', 'logout']);
    expect(cubit.state.status, SessionStatus.unauthenticated);
    await cubit.close();
  });

  blocTest<SessionCubit, SessionState>(
    'si la red avisa que la sesión expiró → unauthenticated (expired)',
    build: build,
    seed: () =>
        const SessionState(status: SessionStatus.authenticated, user: _user),
    act: (cubit) async {
      events.notifyExpired();
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const SessionState(
        status: SessionStatus.unauthenticated,
        endReason: SessionEndReason.expired,
      ),
    ],
  );
}
