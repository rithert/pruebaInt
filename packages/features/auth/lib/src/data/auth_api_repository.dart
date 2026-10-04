import 'package:core/core.dart';

import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';

class AuthApiRepository implements AuthRepository {
  AuthApiRepository({
    required this._api,
    required this._tokenStore,
    required this._cache,
  });

  static const _profileKey = 'auth.profile';
  static const _public = {AuthInterceptor.skipAuthKey: true};

  final ApiClient _api;
  final TokenStore _tokenStore;
  final CacheStore _cache;

  @override
  Future<Result<UserProfile>> register(RegistrationData data) async {
    final result = await _api.post(
      '/v1/auth/register',
      body: {
        'fullName': data.fullName.trim(),
        'email': data.email.trim(),
        'password': data.password,
        'goal': data.goal.apiValue,
        'acceptTerms': true,
      },
      extra: _public,
      decode: _decodeAuthResponse,
    );
    return _openSession(result);
  }

  @override
  Future<Result<UserProfile>> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.post(
      '/v1/auth/login',
      body: {'email': email.trim(), 'password': password},
      extra: _public,
      decode: _decodeAuthResponse,
    );
    return _openSession(result);
  }

  @override
  Future<void> logout() async {
    final tokens = await _tokenStore.read();
    if (tokens != null) {
      // Mejor esfuerzo: si no hay red, la sesión expira sola en el BFF y
      // los datos locales se borran igual.
      await _api.post<void>(
        '/v1/auth/logout',
        body: {'refreshToken': tokens.refreshToken},
        extra: {..._public, RetryInterceptor.disableKey: true},
        decode: (_) {},
      );
    }
    await _tokenStore.clear();
    await _cache.clear();
  }

  @override
  Future<bool> hasStoredSession() async => await _tokenStore.read() != null;

  @override
  Future<UserProfile?> cachedProfile() async {
    final entry = await _cache.read(_profileKey);
    if (entry == null) return null;
    try {
      return UserProfile.fromJson(entry.json! as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  @override
  Future<Result<UserProfile>> fetchProfile() async {
    final result = await _api.get(
      '/v1/me',
      decode: (json) => UserProfile.fromJson(json! as Map<String, Object?>),
    );
    if (result case Success(:final value)) {
      await _cache.write(_profileKey, value.toJson());
    }
    return result;
  }

  Future<Result<UserProfile>> _openSession(
    Result<({UserProfile user, SessionTokens tokens})> result,
  ) async {
    switch (result) {
      case Success(:final value):
        await _tokenStore.save(value.tokens);
        await _cache.write(_profileKey, value.user.toJson());
        return Success(value.user);
      case Failure(:final failure):
        return Failure(failure);
    }
  }

  static ({UserProfile user, SessionTokens tokens}) _decodeAuthResponse(
    Object? json,
  ) {
    final body = json! as Map<String, Object?>;
    return (
      user: UserProfile.fromJson(body['user']! as Map<String, Object?>),
      tokens: SessionTokens.fromJson(body['session']! as Map<String, Object?>),
    );
  }
}
