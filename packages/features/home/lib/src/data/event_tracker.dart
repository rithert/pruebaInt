import 'dart:async';

import 'package:core/core.dart';

/// Envía eventos de uso al BFF en lotes (no una petición por toque).
///
/// Si el envío falla, los eventos vuelven a la cola y salen en el siguiente
/// lote; la cola está acotada para no crecer sin límite sin conexión.
class EventTracker {
  EventTracker(
    this._api, {
    this.flushInterval = const Duration(seconds: 10),
    this.maxQueue = 100,
  });

  static const _batchSize = 50;

  final ApiClient _api;
  final Duration flushInterval;
  final int maxQueue;

  final List<Map<String, String>> _queue = [];
  Timer? _timer;
  bool _flushing = false;

  int get pending => _queue.length;

  void track(String type, String componentId) {
    _queue.add({'type': type, 'componentId': componentId});
    // Sin red la cola no crece sin límite: se descarta lo más viejo.
    if (_queue.length > maxQueue) _queue.removeAt(0);
    _timer ??= Timer(flushInterval, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;

    final batch = _queue.take(_batchSize).toList();
    _queue.removeRange(0, batch.length);
    final result = await _api.post<void>(
      '/v1/events',
      body: {'events': batch},
      decode: (_) {},
    );
    _flushing = false;

    if (result is Failure) {
      _queue.insertAll(0, batch);
      if (_queue.length > maxQueue) {
        _queue.removeRange(0, _queue.length - maxQueue);
      }
    } else if (_queue.isNotEmpty) {
      _timer ??= Timer(flushInterval, () => unawaited(flush()));
    }
  }

  Future<void> dispose() async {
    await flush();
    _timer?.cancel();
  }
}
