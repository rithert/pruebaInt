import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Última respuesta conocida de cada recurso, para mostrar datos sin red.
@DataClassName('CacheRow')
class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Base de datos local de la app. Las migraciones se versionan con
/// [schemaVersion]; nunca se modifica una tabla sin su migración.
@DriftDatabase(tables: [CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Base de datos en el almacenamiento privado de la app.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'super_app'));

  @override
  int get schemaVersion => 1;
}
