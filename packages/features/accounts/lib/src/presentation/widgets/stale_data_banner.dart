import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/formatters.dart';

/// Banner persistente cuando lo que se muestra viene de caché: el usuario
/// nunca debe confundir un saldo viejo con uno actual.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    required this.updatedAt,
    required this.onRetry,
    this.failure,
    super.key,
  });

  final DateTime? updatedAt;
  final AppFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final reason = switch (failure) {
      NoConnectionFailure() => 'Sin conexión',
      ServiceUnavailableFailure() || TimeoutFailure() => 'Servicio con demoras',
      _ => 'No pudimos actualizar',
    };
    final age = updatedAt == null
        ? ''
        : ' · datos de ${Formatters.relative(updatedAt!, now: DateTime.now())}';

    return InlineMessage(
      '$reason$age',
      tone: InlineMessageTone.warning,
      action: TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    );
  }
}
