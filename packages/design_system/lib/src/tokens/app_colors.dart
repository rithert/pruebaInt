import 'package:flutter/material.dart';

/// Paleta de marca. Los colores semánticos (éxito, error, advertencia) se
/// eligieron para cumplir contraste WCAG AA sobre fondos claros y oscuros.
abstract final class AppColors {
  /// Naranja institucional: semilla de todo el esquema de color.
  static const brand = Color(0xFFF7901E);
  static const success = Color(0xFF1E7F4F);
  static const warning = Color(0xFFB25E00);
  static const danger = Color(0xFFC62828);

  /// Montos positivos (abonos) en movimientos, sobre fondo claro.
  static const credit = success;
  static const debit = Color(0xFF37474F);

  /// Verde de abonos legible en ambos temas: sobre fondo oscuro el verde
  /// institucional no alcanza contraste AA, así que se usa uno más claro.
  static Color creditFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF7BD8A4)
      : credit;
}
