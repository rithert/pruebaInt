import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Temas claro y oscuro de la aplicación, derivados de un único color semilla.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      // `fidelity` mantiene el primario cerca del naranja de marca; la
      // variante por defecto lo apagaría hacia un marrón.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      error: AppColors.danger,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      cardTheme: CardThemeData(shape: shape, margin: EdgeInsets.zero),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
      ),
    );
  }
}
