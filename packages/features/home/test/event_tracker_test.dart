import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/home.dart';

void main() {
  late FakeAdapter adapter;
  late EventTracker tracker;

  setUp(() {
    adapter = FakeAdapter();
    tracker = EventTracker(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      ),
      flushInterval: const Duration(hours: 1),
      maxQueue: 3,
    );
  });

  test('agrupa los eventos en un solo envío', () async {
    adapter.enqueueJson(202, {'accepted': 2});
    tracker
      ..track('tapped', 'quick_actions.transfer')
      ..track('dismissed', 'promo.saver');

    await tracker.flush();

    expect(adapter.requests.single.path, '/v1/events');
    expect(adapter.requests.single.data, {
      'events': [
        {'type': 'tapped', 'componentId': 'quick_actions.transfer'},
        {'type': 'dismissed', 'componentId': 'promo.saver'},
      ],
    });
    expect(tracker.pending, 0);
  });

  test('si el envío falla, los eventos se conservan para el próximo', () async {
    adapter
      ..enqueueTransportError(DioExceptionType.connectionError)
      ..enqueueJson(202, {'accepted': 1});
    tracker.track('tapped', 'a');

    await tracker.flush();
    expect(tracker.pending, 1);

    await tracker.flush();
    expect(tracker.pending, 0);
    expect(adapter.requests, hasLength(2));
  });

  test('la cola está acotada: sin red descarta lo más viejo', () {
    for (final id in ['a', 'b', 'c', 'd']) {
      tracker.track('tapped', id);
    }

    expect(tracker.pending, 3);
  });

  test('flush sin eventos no hace peticiones', () async {
    await tracker.flush();

    expect(adapter.requests, isEmpty);
  });
}
