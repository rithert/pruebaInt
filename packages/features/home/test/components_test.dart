import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/home.dart';
import 'package:sdui/sdui.dart';

class _RecordingActions implements SduiActions {
  final routes = <String>[];
  final events = <String>[];
  final dismissed = <String>[];

  @override
  void navigate(String route) => routes.add(route);

  @override
  void track(String type, String componentId) =>
      events.add('$type:$componentId');

  @override
  void dismiss(String componentId) => dismissed.add(componentId);
}

void main() {
  late SduiRegistry registry;
  late _RecordingActions actions;

  setUp(() {
    registry = SduiRegistry();
    HomeModule().registerSduiComponents(registry);
    actions = _RecordingActions();
  });

  Future<void> pump(WidgetTester tester, List<SduiComponent> components) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SduiView(
              layout: SduiLayout(
                schemaVersion: 1,
                layoutId: 'test',
                components: components,
              ),
              registry: registry,
              actions: actions,
            ),
          ),
        ),
      );

  test('aporta los componentes genéricos del home al catálogo', () {
    expect(
      registry.supported.keys,
      containsAll(['greeting', 'insight', 'quick_actions', 'promo_banner']),
    );
  });

  testWidgets('insight: acción navega y registra; se puede descartar', (
    tester,
  ) async {
    await pump(tester, const [
      SduiComponent(
        id: 'insight.income_received',
        type: 'insight',
        props: {
          'tone': 'success',
          'title': r'Recibiste $850,00 esta semana',
          'body': '¿Separas una parte?',
          'dismissible': true,
          'action': {'label': 'Ahorrar ahora', 'route': '/transfer'},
        },
      ),
    ]);

    await tester.tap(find.text('Ahorrar ahora'));
    await tester.tap(find.byTooltip('Descartar'));

    expect(find.text(r'Recibiste $850,00 esta semana'), findsOneWidget);
    expect(actions.routes, ['/transfer']);
    expect(actions.events, ['tapped:insight.income_received']);
    expect(actions.dismissed, ['insight.income_received']);
  });

  testWidgets('acciones rápidas respetan el orden del servidor', (
    tester,
  ) async {
    await pump(tester, const [
      SduiComponent(
        id: 'quick_actions',
        type: 'quick_actions',
        props: {
          'actions': [
            {
              'id': 'support',
              'label': 'Ayuda',
              'icon': 'support',
              'route': '/diagnostics',
            },
            {
              'id': 'transfer',
              'label': 'Transferir',
              'icon': 'transfer',
              'route': '/transfer',
            },
          ],
        },
      ),
    ]);

    final ayuda = tester.getTopLeft(find.text('Ayuda'));
    final transferir = tester.getTopLeft(find.text('Transferir'));
    await tester.tap(find.text('Transferir'));

    expect(ayuda.dx, lessThan(transferir.dx));
    expect(actions.events, ['tapped:quick_actions.transfer']);
  });

  testWidgets('props con tipos inesperados no rompen la pantalla', (
    tester,
  ) async {
    await pump(tester, const [
      SduiComponent(id: 'g', type: 'greeting', props: {'title': 42}),
      SduiComponent(id: 'q', type: 'quick_actions', props: {'actions': 'x'}),
    ]);

    expect(find.text('Hola'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
