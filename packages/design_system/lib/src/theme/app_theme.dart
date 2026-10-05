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
    final base = ThemeData(brightness: brightness).textTheme;
    const strong = TextStyle(fontWeight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Títulos con más peso: jerarquía clara sin agregar una fuente propia.
      textTheme: base.copyWith(
        headlineMedium: base.headlineMedium?.merge(strong),
        headlineSmall: base.headlineSmall?.merge(strong),
        titleLarge: base.titleLarge?.merge(strong),
        titleMedium: base.titleMedium?.merge(strong),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      // Tarjetas planas con borde suave: se leen igual en claro y oscuro.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
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
