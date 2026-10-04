import 'package:core/core.dart';

class DelegatedToken {
  const DelegatedToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

class MiniAppsRepository {
  MiniAppsRepository(this._api);

  final ApiClient _api;

  /// Token de alcance limitado para que la mini app actúe en nombre del
  /// cliente sin conocer su sesión.
  Future<Result<DelegatedToken>> issueToken(String appId) => _api.post(
    '/v1/mini-apps/$appId/token',
    decode: (json) {
      final body = json! as Map<String, Object?>;
      return DelegatedToken(
        token: body['token']! as String,
        expiresAt: DateTime.parse(body['expiresAt']! as String),
      );
    },
  );

  /// Crea la solicitud de crédito con la sesión del cliente (no la mini app).
  Future<Result<String>> requestCredit({
    required int amountMinor,
    required int termMonths,
  }) => _api.post(
    '/v1/credit/applications',
    body: {'amountMinor': amountMinor, 'termMonths': termMonths},
    decode: (json) =>
        (json! as Map<String, Object?>)['applicationId']! as String,
  );
}
