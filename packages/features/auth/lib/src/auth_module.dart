import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'data/auth_api_repository.dart';
import 'domain/auth_repository.dart';
import 'login/login_cubit.dart';
import 'login/login_page.dart';
import 'onboarding/onboarding_cubit.dart';
import 'onboarding/onboarding_page.dart';
import 'session/biometric_authenticator.dart';
import 'session/session_cubit.dart';
import 'unlock/unlock_page.dart';

abstract final class AuthRoutes {
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const unlock = '/unlock';

  /// Rutas accesibles sin sesión.
  static const public = {login, onboarding};
}

class AuthModule implements FeatureModule {
  /// [biometrics] se puede sustituir en tests o en dispositivos sin soporte.
  AuthModule({this._biometrics});

  final BiometricAuthenticator? _biometrics;

  @override
  String get name => 'auth';

  @override
  void registerDependencies(GetIt di) {
    di
      ..registerLazySingleton<AuthRepository>(
        () => AuthApiRepository(
          api: di<ApiClient>(),
          tokenStore: di<TokenStore>(),
          cache: di<CacheStore>(),
        ),
      )
      ..registerLazySingleton<BiometricAuthenticator>(
        () => _biometrics ?? LocalAuthBiometricAuthenticator(),
      )
      ..registerLazySingleton<SessionCubit>(
        () => SessionCubit(
          repository: di<AuthRepository>(),
          biometrics: di<BiometricAuthenticator>(),
          telemetry: di<Telemetry>(),
          sessionEvents: di<SessionEvents>(),
        ),
        dispose: (cubit) => cubit.close(),
      );
  }

  @override
  List<RouteBase> routes(GetIt di) => [
    GoRoute(
      path: AuthRoutes.login,
      builder: (context, state) => BlocProvider(
        create: (_) => LoginCubit(
          repository: di<AuthRepository>(),
          onSignedIn: di<SessionCubit>().signedIn,
        ),
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: AuthRoutes.onboarding,
      builder: (context, state) => BlocProvider(
        create: (_) => OnboardingCubit(
          repository: di<AuthRepository>(),
          onRegistered: di<SessionCubit>().signedIn,
        ),
        child: const OnboardingPage(),
      ),
    ),
    GoRoute(
      path: AuthRoutes.unlock,
      builder: (context, state) => const UnlockPage(),
    ),
  ];
}
