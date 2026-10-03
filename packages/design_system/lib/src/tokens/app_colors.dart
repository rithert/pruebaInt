import 'package:flutter/material.dart';

/// Paleta de marca. Los colores semánticos (éxito, error, advertencia) se
/// eligieron para cumplir contraste WCAG AA sobre fondos claros y oscuros.
abstract final class AppColors {
  static const brand = Color(0xFF0B5FFF);
  static const success = Color(0xFF1E7F4F);
  static const warning = Color(0xFFB25E00);
  static const danger = Color(0xFFC62828);

  /// Montos positivos (abonos) y negativos (cargos) en movimientos.
  static const credit = success;
  static const debit = Color(0xFF37474F);
}
