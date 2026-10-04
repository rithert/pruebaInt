import 'dart:convert';

/// Versión del protocolo del bridge app ↔ mini app.
const bridgeProtocolVersion = 1;

/// Mensajes que la mini app puede enviar a la app. Es `sealed`: un mensaje
/// que no esté aquí no existe para la app.
sealed class BridgeInbound {
  const BridgeInbound();
}

/// La mini app cargó y espera el contexto.
final class BridgeReady extends BridgeInbound {
  const BridgeReady();
}

/// El token delegado expiró; la mini app pide uno nuevo.
final class BridgeGetToken extends BridgeInbound {
  const BridgeGetToken();
}

/// El usuario quiere solicitar el crédito cotizado. La app debe CONFIRMAR
/// con el usuario antes de ejecutarlo: la mini app solo lo propone.
final class BridgeRequestCredit extends BridgeInbound {
  const BridgeRequestCredit({
    required this.amountMinor,
    required this.termMonths,
    required this.monthlyPaymentMinor,
  });

  final int amountMinor;
  final int termMonths;
  final int monthlyPaymentMinor;
}

final class BridgeClose extends BridgeInbound {
  const BridgeClose();
}

/// Interpreta un mensaje crudo de la mini app. Devuelve `null` si no es
/// válido (JSON roto, otra versión, tipo desconocido o payload incorrecto):
/// el contenido de un tercero nunca se ejecuta a ciegas.
BridgeInbound? parseBridgeMessage(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;
  if (decoded['v'] != bridgeProtocolVersion) return null;

  final payload = decoded['payload'] is Map<String, Object?>
      ? decoded['payload']! as Map<String, Object?>
      : const <String, Object?>{};

  return switch (decoded['type']) {
    'ready' => const BridgeReady(),
    'get_token' => const BridgeGetToken(),
    'close' => const BridgeClose(),
    'request_credit' => _requestCredit(payload),
    _ => null,
  };
}

BridgeRequestCredit? _requestCredit(Map<String, Object?> payload) {
  final amount = payload['amountMinor'];
  final term = payload['termMonths'];
  final monthly = payload['monthlyPaymentMinor'];
  if (amount is! int || term is! int || monthly is! int) return null;
  if (amount <= 0 || term <= 0 || monthly <= 0) return null;
  return BridgeRequestCredit(
    amountMinor: amount,
    termMonths: term,
    monthlyPaymentMinor: monthly,
  );
}

/// Script que entrega un mensaje a la mini app. `jsonEncode` del texto lo
/// escapa como literal de JS: el contenido no puede inyectar código.
String bridgeDeliveryScript(String type, Map<String, Object?> payload) {
  final message = jsonEncode({
    'v': bridgeProtocolVersion,
    'id': DateTime.now().microsecondsSinceEpoch.toString(),
    'type': type,
    'payload': payload,
  });
  return 'window.SuperAppBridge && '
      'window.SuperAppBridge.receive(${jsonEncode(message)});';
}
