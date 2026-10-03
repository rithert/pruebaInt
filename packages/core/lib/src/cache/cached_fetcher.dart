import '../result/app_failure.dart';
import '../result/result.dart';
import 'cache_store.dart';

/// Estado de un recurso que puede venir de caché, de la red o de ambos.
///
/// La UI decide qué mostrar combinando los campos:
/// - `data == null && isRefreshing` → skeleton de carga.
/// - `data != null && isRefreshing` → datos + indicador sutil de actualización.
/// - `data != null && failure != null` → datos en caché + aviso "actualizado hace X".
/// - `data == null && failure != null` → pantalla de error con reintentar.
class Resource<T> {
  const Resource({
    this.data,
    this.updatedAt,
    this.isRefreshing = false,
    this.failure,
  });

  final T? data;

  /// Momento en que se obtuvieron los datos mostrados.
  final DateTime? updatedAt;
  final bool isRefreshing;

  /// Falla de la última actualización (los datos pueden seguir siendo útiles).
  final AppFailure? failure;

  bool get hasData => data != null;

  /// Se muestran datos de caché porque la actualización falló.
  bool get isStale => hasData && failure != null;
}

/// Implementa *stale-while-revalidate*: emite primero lo que hay en caché
/// (respuesta instantánea, también sin red) y luego lo que trae el servidor.
/// Si el servidor falla, conserva los datos en caché junto con la falla.
class CachedFetcher {
  CachedFetcher(this._cache, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final CacheStore _cache;
  final DateTime Function() _now;

  Stream<Resource<T>> watch<T>({
    required String key,
    required Future<Result<Object?>> Function() fetch,
    required T Function(Object? json) decode,
  }) async* {
    final cached = await _readCache(key, decode);
    yield Resource(
      data: cached?.data,
      updatedAt: cached?.updatedAt,
      isRefreshing: true,
    );

    switch (await fetch()) {
      case Success(:final value):
        final T data;
        try {
          data = decode(value);
        } on Object catch (error) {
          yield Resource(
            data: cached?.data,
            updatedAt: cached?.updatedAt,
            failure: UnexpectedFailure(cause: error),
          );
          return;
        }
        final updatedAt = _now();
        await _cache.write(key, value, updatedAt: updatedAt);
        yield Resource(data: data, updatedAt: updatedAt);
      case Failure(:final failure):
        yield Resource(
          data: cached?.data,
          updatedAt: cached?.updatedAt,
          failure: failure,
        );
    }
  }

  Future<({T data, DateTime updatedAt})?> _readCache<T>(
    String key,
    T Function(Object? json) decode,
  ) async {
    try {
      final entry = await _cache.read(key);
      if (entry == null) return null;
      return (data: decode(entry.json), updatedAt: entry.updatedAt);
    } on Object {
      // Caché ilegible (p. ej. cambió el formato tras una actualización):
      // se ignora y se depende de la red.
      return null;
    }
  }
}
