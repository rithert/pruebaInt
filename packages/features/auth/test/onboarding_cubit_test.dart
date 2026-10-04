import 'package:auth/auth.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Especificación del OnboardingCubit: wizard de 3 pasos con validación por
/// paso, envío al BFF y mapeo de errores del servidor a campos concretos.

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = UserProfile(
  id: 'u1',
  email: 'ana@example.com',
  fullName: 'Ana Gómez',
  goal: FinancialGoal.save,
  segment: 'saver',
);

/// Estado listo para enviar: los 3 pasos completos y válidos.
const _filled = OnboardingState(
  step: OnboardingStep.credentials,
  fullName: 'Ana Gómez',
  email: 'ana@example.com',
  goal: FinancialGoal.save,
  password: 'Segura123',
  acceptTerms: true,
);

void main() {
  late _MockAuthRepository repository;
  late List<UserProfile> registered;

  setUpAll(() {
    registerFallbackValue(
      const RegistrationData(
        fullName: '',
        email: '',
        password: '',
        goal: FinancialGoal.save,
      ),
    );
  });

  setUp(() {
    repository = _MockAuthRepository();
    registered = [];
  });

  OnboardingCubit build() =>
      OnboardingCubit(repository: repository, onRegistered: registered.add);

  void stubRegister(Result<UserProfile> result) =>
      when(() => repository.register(any())).thenAnswer((_) async => result);

  test('arranca en el paso 1 sin datos ni errores', () {
    expect(build().state, const OnboardingState());
  });

  group('edición de campos', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'actualiza el valor y borra el error de ESE campo',
      build: build,
      seed: () => const OnboardingState(
        fieldErrors: {
          OnboardingField.fullName: 'x',
          OnboardingField.email: 'y',
        },
      ),
      act: (cubit) => cubit.emailChanged('ana@example.com'),
      expect: () => [
        const OnboardingState(
          email: 'ana@example.com',
          fieldErrors: {OnboardingField.fullName: 'x'},
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'registra nombre, objetivo, contraseña y términos',
      build: build,
      act: (cubit) => cubit
        ..fullNameChanged('Ana')
        ..goalSelected(FinancialGoal.invest)
        ..passwordChanged('abc')
        ..acceptTermsChanged(true),
      verify: (cubit) {
        expect(cubit.state.fullName, 'Ana');
        expect(cubit.state.goal, FinancialGoal.invest);
        expect(cubit.state.password, 'abc');
        expect(cubit.state.acceptTerms, isTrue);
      },
    );
  });

  group('navegación entre pasos', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'paso 1 inválido: muestra errores y NO avanza',
      build: build,
      seed: () => const OnboardingState(fullName: 'A', email: 'no-es-correo'),
      act: (cubit) => cubit.next(),
      expect: () => [
        OnboardingState(
          fullName: 'A',
          email: 'no-es-correo',
          fieldErrors: {
            OnboardingField.fullName: Validators.fullName('A')!,
            OnboardingField.email: Validators.email('no-es-correo')!,
          },
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'paso 1 válido: avanza al objetivo',
      build: build,
      seed: () => const OnboardingState(
        fullName: 'Ana Gómez',
        email: 'ana@example.com',
      ),
      act: (cubit) => cubit.next(),
      expect: () => [
        const OnboardingState(
          step: OnboardingStep.goal,
          fullName: 'Ana Gómez',
          email: 'ana@example.com',
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'paso 2 sin objetivo: pide elegir uno',
      build: build,
      seed: () => const OnboardingState(step: OnboardingStep.goal),
      act: (cubit) => cubit.next(),
      expect: () => [
        const OnboardingState(
          step: OnboardingStep.goal,
          fieldErrors: {OnboardingField.goal: OnboardingMessages.goalRequired},
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'paso 2 con objetivo: avanza a credenciales',
      build: build,
      seed: () => const OnboardingState(
        step: OnboardingStep.goal,
        goal: FinancialGoal.invest,
      ),
      act: (cubit) => cubit.next(),
      expect: () => [
        const OnboardingState(
          step: OnboardingStep.credentials,
          goal: FinancialGoal.invest,
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'next() en el último paso no hace nada (se usa submit)',
      build: build,
      seed: () => _filled,
      act: (cubit) => cubit.next(),
      expect: () => <OnboardingState>[],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'back() retrocede conservando los datos ingresados',
      build: build,
      seed: () => _filled,
      act: (cubit) => cubit.back(),
      expect: () => [_filled.copyWith(step: OnboardingStep.goal)],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'back() en el primer paso no hace nada',
      build: build,
      act: (cubit) => cubit.back(),
      expect: () => <OnboardingState>[],
    );
  });

  group('envío', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'credenciales inválidas: errores en el paso 3 sin llamar al servidor',
      build: build,
      seed: () => _filled.copyWith(password: 'corta', acceptTerms: false),
      act: (cubit) => cubit.submit(),
      expect: () => [
        _filled.copyWith(
          password: 'corta',
          acceptTerms: false,
          fieldErrors: {
            OnboardingField.password: Validators.password('corta')!,
            OnboardingField.acceptTerms: OnboardingMessages.termsRequired,
          },
        ),
      ],
      verify: (_) => verifyNever(() => repository.register(any())),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'éxito: envía los datos, queda en submitting y notifica el registro',
      build: build,
      setUp: () => stubRegister(const Success(_user)),
      seed: () => _filled,
      act: (cubit) => cubit.submit(),
      expect: () => [_filled.copyWith(status: OnboardingStatus.submitting)],
      verify: (_) {
        final data =
            verify(() => repository.register(captureAny())).captured.single
                as RegistrationData;
        expect(data.fullName, 'Ana Gómez');
        expect(data.email, 'ana@example.com');
        expect(data.password, 'Segura123');
        expect(data.goal, FinancialGoal.save);
        expect(registered, [_user]);
      },
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'ignora un segundo submit mientras envía (doble toque)',
      build: build,
      setUp: () => stubRegister(const Success(_user)),
      seed: () => _filled,
      act: (cubit) async {
        final first = cubit.submit();
        await cubit.submit();
        await first;
      },
      verify: (_) => verify(() => repository.register(any())).called(1),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'submit() fuera del paso 3 no hace nada',
      build: build,
      seed: () => _filled.copyWith(step: OnboardingStep.goal),
      act: (cubit) => cubit.submit(),
      expect: () => <OnboardingState>[],
    );
  });

  group('errores del servidor', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'correo ya registrado: vuelve al paso 1 con el error en el correo',
      build: build,
      setUp: () => stubRegister(
        const Failure(
          BusinessFailure(code: 'email_taken', serverMessage: 'Ya existe'),
        ),
      ),
      seed: () => _filled,
      act: (cubit) => cubit.submit(),
      expect: () => [
        _filled.copyWith(status: OnboardingStatus.submitting),
        _filled.copyWith(
          step: OnboardingStep.personalData,
          fieldErrors: {OnboardingField.email: OnboardingMessages.emailTaken},
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'validación del servidor: lleva al paso del campo rechazado',
      build: build,
      setUp: () => stubRegister(
        const Failure(
          ValidationFailure(fieldErrors: {'fullName': 'Nombre no permitido'}),
        ),
      ),
      seed: () => _filled,
      act: (cubit) => cubit.submit(),
      expect: () => [
        _filled.copyWith(status: OnboardingStatus.submitting),
        _filled.copyWith(
          step: OnboardingStep.personalData,
          fieldErrors: {OnboardingField.fullName: 'Nombre no permitido'},
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'validación del servidor en la contraseña: se queda en el paso 3',
      build: build,
      setUp: () => stubRegister(
        const Failure(
          ValidationFailure(fieldErrors: {'password': 'Muy común'}),
        ),
      ),
      seed: () => _filled,
      act: (cubit) => cubit.submit(),
      expect: () => [
        _filled.copyWith(status: OnboardingStatus.submitting),
        _filled.copyWith(fieldErrors: {OnboardingField.password: 'Muy común'}),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'falla general (sin red): conserva todo y expone la falla',
      build: build,
      setUp: () => stubRegister(const Failure(NoConnectionFailure())),
      seed: () => _filled,
      act: (cubit) => cubit.submit(),
      expect: () => [
        _filled.copyWith(status: OnboardingStatus.submitting),
        _filled.copyWith(
          status: OnboardingStatus.failure,
          failure: () => const NoConnectionFailure(),
        ),
      ],
      verify: (_) => expect(registered, isEmpty),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'reintentar tras una falla general limpia la falla anterior',
      build: build,
      setUp: () => stubRegister(const Success(_user)),
      seed: () => _filled.copyWith(
        status: OnboardingStatus.failure,
        failure: () => const NoConnectionFailure(),
      ),
      act: (cubit) => cubit.submit(),
      expect: () => [_filled.copyWith(status: OnboardingStatus.submitting)],
    );
  });
}
