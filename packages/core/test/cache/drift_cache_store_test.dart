import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftCacheStore(db);
  });
  tearDown(() => db.close());

  test('guarda y recupera JSON con su fecha', () async {
    final at = DateTime(2026, 10, 3, 12);
    await store.write('accounts', {
      'items': [1, 2],
    }, updatedAt: at);

    final entry = await store.read('accounts');

    expect(entry?.json, {
      'items': [1, 2],
    });
    expect(entry?.updatedAt, at);
  });

  test('sobrescribe la entrada existente', () async {
    await store.write('k', 'a');
    await store.write('k', 'b');

    expect((await store.read('k'))?.json, 'b');
  });

  test('clear elimina todos los datos (logout)', () async {
    await store.write('a', 1);
    await store.write('b', 2);

    await store.clear();

    expect(await store.read('a'), isNull);
    expect(await store.read('b'), isNull);
  });
}
