import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens de la sesión vigente.
class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken});

  factory SessionTokens.fromJson(Map<String, Object?> json) => SessionTokens(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
  );

  final String accessToken;
  final String refreshToken;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

abstract interface class TokenStore {
  Future<SessionTokens?> read();
  Future<void> save(SessionTokens tokens);
  Future<void> clear();
}

/// Guarda los tokens cifrados con Android Keystore (EncryptedSharedPreferences
/// bajo el capó). Nunca en SharedPreferences ni en la base de datos de caché.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session_tokens';
  final FlutterSecureStorage _storage;

  @override
  Future<SessionTokens?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return SessionTokens.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      // Datos corruptos: se descartan y el usuario vuelve a iniciar sesión.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(SessionTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Implementación en memoria para tests.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  SessionTokens? _tokens;

  @override
  Future<SessionTokens?> read() async => _tokens;

  @override
  Future<void> save(SessionTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
