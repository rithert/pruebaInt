import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('muestra el monto con cifras tabulares', (tester) async {
    await pump(tester, const AmountText(r'$1.284,30'));

    final text = tester.widget<Text>(find.text(r'$1.284,30'));
    expect(
      text.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('oculto: no muestra ni anuncia la cifra', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const AmountText(
        r'$1.284,30',
        hidden: true,
        semanticsLabel: 'Saldo total',
      ),
    );

    expect(find.text(r'$1.284,30'), findsNothing);
    expect(find.text(AmountText.mask), findsOneWidget);
    expect(find.bySemanticsLabel('Saldo total: oculto'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1.284')), findsNothing);
    handle.dispose();
  });

  testWidgets('los abonos usan el verde accesible del tema', (tester) async {
    await pump(tester, const AmountText(r'+$50,00', tone: AmountTone.credit));

    final text = tester.widget<Text>(find.text(r'+$50,00'));
    expect(text.style?.color, AppColors.credit);
  });
}
