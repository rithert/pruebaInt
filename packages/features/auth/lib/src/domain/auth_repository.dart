import 'package:core/core.dart';

import 'user_profile.dart';

class RegistrationData {
  const RegistrationData({
    required this.fullName,
    required this.email,
    required this.password,
    required this.goal,
  });

  final String fullName;
  final String email;
  final String password;
  final FinancialGoal goal;
}

/// Contrato del dominio de identidad. Las operaciones que abren sesión
/// guardan los tokens de forma segura antes de devolver el perfil.
abstract interface class AuthRepository {
  Future<Result<UserProfile>> register(RegistrationData data);

  Future<Result<UserProfile>> login({
    required String email,
    required String password,
  });

  /// Revoca la sesión en el BFF (mejor esfuerzo) y borra los datos locales.
  Future<void> logout();

  /// ¿Hay tokens guardados de una sesión anterior?
  Future<bool> hasStoredSession();

  /// Último perfil conocido, disponible sin red.
  Future<UserProfile?> cachedProfile();

  /// Perfil actualizado desde el BFF.
  Future<Result<UserProfile>> fetchProfile();
}
