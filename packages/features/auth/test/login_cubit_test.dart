import 'package:auth/auth.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = UserProfile(
  id: 'u1',
  email: 'ana@example.com',
  fullName: 'Ana Gómez',
  goal: FinancialGoal.save,
  segment: 'saver',
);

void main() {
  late _MockAuthRepository repository;
  late List<UserProfile> signedIn;

  setUp(() {
    repository = _MockAuthRepository();
    signedIn = [];
  });

  LoginCubit build() =>
      LoginCubit(repository: repository, onSignedIn: signedIn.add);

  void stubLogin(Result<UserProfile> result) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  blocTest<LoginCubit, LoginState>(
    'valida antes de llamar al servidor',
    build: build,
    act: (cubit) => cubit.submit(),
    expect: () => [
      LoginState(
        emailError: Validators.email(''),
        passwordError: Validators.requiredField(''),
      ),
    ],
    verify: (_) => verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ),
  );

  blocTest<LoginCubit, LoginState>(
    'éxito: notifica el usuario autenticado',
    setUp: () => stubLogin(const Success(_user)),
    build: build,
    seed: () =>
        const LoginState(email: 'ana@example.com', password: 'Segura123'),
    act: (cubit) => cubit.submit(),
    expect: () => [
      const LoginState(
        email: 'ana@example.com',
        password: 'Segura123',
        status: LoginStatus.submitting,
      ),
    ],
    verify: (_) => expect(signedIn, [_user]),
  );

  blocTest<LoginCubit, LoginState>(
    'credenciales inválidas: muestra el error y borra la contraseña',
    setUp: () => stubLogin(
      const Failure(UnauthorizedFailure(code: 'invalid_credentials')),
    ),
    build: build,
    seed: () => const LoginState(email: 'ana@example.com', password: 'mala'),
    act: (cubit) => cubit.submit(),
    skip: 1,
    expect: () => [
      const LoginState(
        email: 'ana@example.com',
        status: LoginStatus.failure,
        failure: UnauthorizedFailure(code: 'invalid_credentials'),
      ),
    ],
  );

  test('mensajes de error del login', () {
    expect(
      loginFailureMessage(
        const UnauthorizedFailure(code: 'invalid_credentials'),
      ),
      'Correo o contraseña incorrectos.',
    );
    expect(
      loginFailureMessage(
        const BusinessFailure(code: 'rate_limited', serverMessage: 'x'),
      ),
      contains('Demasiados intentos'),
    );
    expect(
      loginFailureMessage(const NoConnectionFailure()),
      const NoConnectionFailure().message,
    );
  });
}
