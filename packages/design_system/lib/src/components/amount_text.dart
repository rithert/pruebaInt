import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Color de un monto según su significado, no según su signo.
enum AmountTone { neutral, credit }

/// Monto de dinero ya formateado (el formato depende del dominio).
///
/// - Cifras tabulares: todos los dígitos ocupan el mismo ancho, así los
///   montos en columna quedan alineados y no "bailan" al actualizarse.
/// - [hidden]: modo privacidad. Se reemplaza el valor y el lector de
///   pantalla anuncia "oculto" en lugar de leer la cifra.
class AmountText extends StatelessWidget {
  const AmountText(
    this.formatted, {
    this.hidden = false,
    this.tone = AmountTone.neutral,
    this.style,
    this.semanticsLabel,
    super.key,
  });

  /// Lo que se muestra en lugar del monto cuando está oculto.
  static const mask = r'$ ••••••';

  final String formatted;
  final bool hidden;
  final AmountTone tone;
  final TextStyle? style;

  /// Contexto para el lector de pantalla (p. ej. "Saldo total"). Sin él se
  /// lee solo el monto.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AmountTone.credit => AppColors.creditFor(context),
      AmountTone.neutral => null,
    };
    final prefix = semanticsLabel == null ? '' : '$semanticsLabel: ';

    return Semantics(
      label: hidden ? '${prefix}oculto' : '$prefix$formatted',
      excludeSemantics: true,
      child: Text(
        hidden ? mask : formatted,
        maxLines: 1,
        style: (style ?? DefaultTextStyle.of(context).style).copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
