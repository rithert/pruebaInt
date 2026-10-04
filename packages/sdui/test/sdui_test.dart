import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdui/sdui.dart';

class _NoopActions implements SduiActions {
  @override
  void dismiss(String componentId) {}

  @override
  void navigate(String route) {}

  @override
  void track(String type, String componentId) {}
}

void main() {
  const parser = SduiParser(supported: {'greeting': 1, 'insight': 2});

  Map<String, Object?> layout(List<Object?> components, {int schema = 1}) => {
    'schemaVersion': schema,
    'layoutId': 'home.saver',
    'components': components,
  };

  group('SduiParser', () {
    test('respeta el orden y los props del servidor', () {
      final result = parser.parse(
        layout([
          {
            'id': 'g',
            'type': 'greeting',
            'props': {'title': 'Hola'},
          },
          {'id': 'i', 'type': 'insight', 'version': 2},
        ]),
      );

      expect(result.layout.components.map((c) => c.id), ['g', 'i']);
      expect(result.layout.components.first.props['title'], 'Hola');
      expect(result.skipped, isEmpty);
    });

    test('omite lo desconocido o mal formado SIN invalidar el resto', () {
      final result = parser.parse(
        layout([
          {'id': 'nuevo', 'type': 'componente_del_futuro'},
          {'id': 'v3', 'type': 'insight', 'version': 3},
          {'type': 'greeting'},
          'basura',
          {'id': 'p', 'type': 'greeting', 'props': 'no-es-mapa'},
          {'id': 'ok', 'type': 'greeting'},
          {'id': 'ok', 'type': 'greeting'},
        ]),
      );

      expect(result.layout.components.map((c) => c.id), ['ok']);
      expect(result.skipped, hasLength(6));
    });

    test('un schemaVersion futuro invalida el layout completo', () {
      expect(
        () => parser.parse(layout([], schema: 2)),
        throwsA(isA<SduiSchemaException>()),
      );
    });

    test('rechaza raíces inválidas', () {
      expect(() => parser.parse(null), throwsA(isA<SduiSchemaException>()));
      expect(
        () => parser.parse({'schemaVersion': 1}),
        throwsA(isA<SduiSchemaException>()),
      );
    });
  });

  group('SduiProps', () {
    test('lee con tipos seguros y valores por defecto', () {
      const props = <String, Object?>{'a': 'x', 'b': 3, 'c': true};

      expect(props.string('a'), 'x');
      expect(props.string('b', fallback: '?'), '?');
      expect(props.boolean('c'), isTrue);
      expect(props.stringOrNull('z'), isNull);
      expect(props.listOfMaps('a'), isEmpty);
    });
  });

  testWidgets('SduiView aísla un componente que falla', (tester) async {
    final registry = SduiRegistry()
      ..register('greeting', (context, c, _) => Text(c.props.string('title')))
      ..register('insight', (context, c, _) => throw StateError('props raras'));
    final errors = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SduiView(
          layout: const SduiLayout(
            schemaVersion: 1,
            layoutId: 'x',
            components: [
              SduiComponent(id: 'i', type: 'insight'),
              SduiComponent(
                id: 'g',
                type: 'greeting',
                props: {'title': 'Hola'},
              ),
            ],
          ),
          registry: registry,
          actions: _NoopActions(),
          onComponentError: (c, _) => errors.add(c.id),
        ),
      ),
    );

    expect(find.text('Hola'), findsOneWidget);
    expect(errors, ['i']);
  });
}
