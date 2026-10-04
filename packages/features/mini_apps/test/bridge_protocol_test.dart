import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_apps/mini_apps.dart';

String msg(
  Object? type, [
  Map<String, Object?> payload = const {},
  int v = 1,
]) => jsonEncode({'v': v, 'id': '1', 'type': type, 'payload': payload});

void main() {
  group('parseBridgeMessage', () {
    test('reconoce los mensajes del protocolo v1', () {
      expect(parseBridgeMessage(msg('ready')), isA<BridgeReady>());
      expect(parseBridgeMessage(msg('get_token')), isA<BridgeGetToken>());
      expect(parseBridgeMessage(msg('close')), isA<BridgeClose>());
    });

    test('request_credit trae monto, plazo y cuota tipados', () {
      final message = parseBridgeMessage(
        msg('request_credit', {
          'amountMinor': 500000,
          'termMonths': 24,
          'monthlyPaymentMinor': 24100,
        }),
      );

      expect(message, isA<BridgeRequestCredit>());
      final request = message! as BridgeRequestCredit;
      expect(request.amountMinor, 500000);
      expect(request.termMonths, 24);
    });

    test('rechaza lo que un tercero no debería poder enviar', () {
      expect(parseBridgeMessage('no es json'), isNull);
      expect(parseBridgeMessage('[1,2]'), isNull);
      expect(parseBridgeMessage(msg('ready', const {}, 2)), isNull);
      expect(parseBridgeMessage(msg('transfer_money')), isNull);
      expect(parseBridgeMessage(msg(null)), isNull);
      expect(
        parseBridgeMessage(msg('request_credit', {'amountMinor': '5000'})),
        isNull,
      );
      expect(
        parseBridgeMessage(
          msg('request_credit', {
            'amountMinor': -1,
            'termMonths': 24,
            'monthlyPaymentMinor': 1,
          }),
        ),
        isNull,
      );
    });
  });

  test('bridgeDeliveryScript escapa el contenido (sin inyección de JS)', () {
    final script = bridgeDeliveryScript('context', {
      'firstName': "'); alert('xss'); ('",
    });

    expect(script, startsWith('window.SuperAppBridge && '));
    // El payload viaja como literal de string JSON, nunca como código.
    expect(script, contains(r'\"firstName\"'));
    expect(script, isNot(contains("receive('")));
  });

  test('el catálogo arma la URL y el origen desde el entorno', () {
    final definition = miniAppCatalog(
      'http://localhost:3100',
    )['credit-simulator']!;

    expect(
      definition.entryUrl.toString(),
      'http://localhost:3100/credit-simulator/',
    );
    expect(definition.origin, 'http://localhost:3100');
  });
}
