/// Dominio de identidad: onboarding, inicio de sesión, sesión y desbloqueo
/// biométrico. El shell solo usa [AuthModule] y [SessionCubit].
library;

export 'src/auth_module.dart';
export 'src/data/auth_api_repository.dart';
export 'src/domain/auth_repository.dart';
export 'src/domain/user_profile.dart';
export 'src/domain/validators.dart';
export 'src/login/login_cubit.dart';
export 'src/onboarding/onboarding_cubit.dart';
export 'src/onboarding/onboarding_state.dart';
export 'src/session/biometric_authenticator.dart';
export 'src/session/session_cubit.dart';
