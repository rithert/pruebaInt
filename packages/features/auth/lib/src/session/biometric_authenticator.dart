import 'package:local_auth/local_auth.dart';

/// Puerto de autenticación local (huella, rostro). Se abstrae para poder
/// probar la sesión sin hardware y para cambiar de plugin sin tocar el dominio.
abstract interface class BiometricAuthenticator {
  /// ¿El dispositivo tiene biometría configurada?
  Future<bool> isAvailable();

  Future<bool> authenticate({required String reason});
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      // Cancelado, bloqueado por intentos o error de hardware: no desbloquea.
      return false;
    }
  }
}
