import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('genera temas claro y oscuro con Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    test('los botones principales respetan el área táctil mínima', () {
      final style = AppTheme.light().filledButtonTheme.style!;
      final minSize = style.minimumSize!.resolve(<WidgetState>{})!;

      expect(minSize.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
    });
  });
}
