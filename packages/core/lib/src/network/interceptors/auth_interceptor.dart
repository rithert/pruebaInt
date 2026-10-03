import 'dart:async';

import 'package:dio/dio.dart';

import '../../session/token_store.dart';

/// Renueva la sesión con el refresh token. Devuelve `null` si el BFF la
/// rechaza (expirada, revocada o reutilizada): la sesión terminó.
typedef RefreshSession = Future<SessionTokens?> Function(String refreshToken);

/// Adjunta el access token y renueva la sesión cuando el BFF responde
/// `401 token_expired`.
///
/// **Single-flight:** si varias peticiones expiran a la vez, se hace UN solo
/// refresh y todas esperan su resultado. Es obligatorio por la rotación de
/// refresh tokens del BFF (ADR-0003): dos refresh en paralelo con el mismo
/// token se detectarían como robo y cerrarían la sesión.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required this._tokenStore,
    required this._refresh,
    this._onSessionExpired,
  });

  /// `extra` para peticiones públicas que no deben llevar token.
  static const skipAuthKey = 'skip_auth';
  static const _retriedKey = 'auth_retried';

  final Dio _dio;
  final TokenStore _tokenStore;
  final RefreshSession _refresh;
  final void Function()? _onSessionExpired;

  Future<SessionTokens?>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await _tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[skipAuthKey] == true) {
      return handler.next(err);
    }

    final code = _errorCode(err.response?.data);
    if (code != 'token_expired' || options.extra[_retriedKey] == true) {
      // Token inválido o ya se intentó renovar: la sesión no se puede salvar.
      await _endSession();
      return handler.next(err);
    }

    final SessionTokens? tokens;
    try {
      tokens = await _freshTokens(_bearer(options));
    } on Object {
      // El refresh falló por red o por el servidor, no porque la sesión sea
      // inválida: se conservan los tokens y se propaga el error original.
      // Perder la señal con el token vencido no debe expulsar al usuario.
      return handler.next(err);
    }
    if (tokens == null) {
      await _endSession();
      return handler.next(err);
    }

    try {
      options
        ..headers['Authorization'] = 'Bearer ${tokens.accessToken}'
        ..extra[_retriedKey] = true;
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Tokens válidos para reintentar. Si otra petición ya renovó la sesión
  /// mientras esta esperaba, se usan esos tokens sin volver a refrescar.
  Future<SessionTokens?> _freshTokens(String? usedAccessToken) async {
    final stored = await _tokenStore.read();
    if (stored == null) return null;
    if (stored.accessToken != usedAccessToken) return stored;

    return _refreshInFlight ??= _doRefresh(stored).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<SessionTokens?> _doRefresh(SessionTokens current) async {
    final renewed = await _refresh(current.refreshToken);
    if (renewed != null) await _tokenStore.save(renewed);
    return renewed;
  }

  Future<void> _endSession() async {
    await _tokenStore.clear();
    _onSessionExpired?.call();
  }

  static String? _bearer(RequestOptions options) {
    final header = options.headers['Authorization'] as String?;
    return header?.replaceFirst('Bearer ', '');
  }

  static String? _errorCode(Object? data) {
    if (data is Map<String, Object?> && data['error'] is Map<String, Object?>) {
      return (data['error']! as Map<String, Object?>)['code'] as String?;
    }
    return null;
  }
}
