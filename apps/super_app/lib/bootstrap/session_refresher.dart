import 'package:core/core.dart';
import 'package:dio/dio.dart';

/// Llama a `POST /v1/auth/refresh` con un `Dio` SIN interceptores: si usara
/// el cliente principal, un 401 del refresh volvería a disparar el
/// AuthInterceptor (recursión).
class SessionRefresher {
  SessionRefresher(String baseUrl, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  /// `null` si el BFF rechaza la sesión (401). Errores de red se propagan:
  /// la sesión sigue siendo válida y se reintentará más tarde.
  Future<SessionTokens?> call(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final session = response.data!['session']! as Map<String, Object?>;
      return SessionTokens.fromJson(session);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      rethrow;
    }
  }
}
