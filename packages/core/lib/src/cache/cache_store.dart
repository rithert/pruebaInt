import 'dart:convert';

import 'app_database.dart';

class CacheEntry {
  const CacheEntry({required this.json, required this.updatedAt});

  final Object? json;
  final DateTime updatedAt;
}

/// Caché clave → JSON con fecha de actualización.
abstract interface class CacheStore {
  Future<CacheEntry?> read(String key);
  Future<void> write(String key, Object? json, {DateTime? updatedAt});

  /// Se invoca al cerrar sesión: no deben quedar datos financieros del
  /// cliente anterior en el dispositivo.
  Future<void> clear();
}

class DriftCacheStore implements CacheStore {
  DriftCacheStore(this._db);

  final AppDatabase _db;

  @override
  Future<CacheEntry?> read(String key) async {
    final row = await (_db.select(
      _db.cacheEntries,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return CacheEntry(json: jsonDecode(row.payload), updatedAt: row.updatedAt);
  }

  @override
  Future<void> write(String key, Object? json, {DateTime? updatedAt}) => _db
      .into(_db.cacheEntries)
      .insertOnConflictUpdate(
        CacheEntriesCompanion.insert(
          key: key,
          payload: jsonEncode(json),
          updatedAt: updatedAt ?? DateTime.now(),
        ),
      );

  @override
  Future<void> clear() => _db.delete(_db.cacheEntries).go();
}

/// Implementación en memoria para tests de repositorios y cubits.
class InMemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> _entries = {};

  @override
  Future<CacheEntry?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, Object? json, {DateTime? updatedAt}) async {
    _entries[key] = CacheEntry(
      json: json,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> clear() async => _entries.clear();
}
