import 'package:accounts/accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 3, 15);

  group('money', () {
    test('formatea pesos con separador de miles y sin decimales', () {
      expect(Formatters.money(128430000), r'$ 1.284.300');
      expect(Formatters.money(0), r'$ 0');
      expect(Formatters.money(99900), r'$ 999');
      expect(Formatters.money(-4520000), r'-$ 45.200');
    });

    test('signedMoney antepone + a los abonos', () {
      expect(Formatters.signedMoney(180000000), r'+$ 1.800.000');
      expect(Formatters.signedMoney(-1200000), r'-$ 12.000');
    });
  });

  group('fechas', () {
    test('dayLabel: Hoy, Ayer, fecha corta y año si es otro', () {
      expect(Formatters.dayLabel(DateTime(2026, 10, 3, 8), now: now), 'Hoy');
      expect(Formatters.dayLabel(DateTime(2026, 10, 2, 23), now: now), 'Ayer');
      expect(Formatters.dayLabel(DateTime(2026, 9, 28), now: now), '28 sep');
      expect(
        Formatters.dayLabel(DateTime(2025, 12, 24), now: now),
        '24 dic 2025',
      );
    });

    test('relative describe la antigüedad de los datos', () {
      expect(
        Formatters.relative(now.subtract(const Duration(seconds: 20)), now: now),
        'hace un momento',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(minutes: 5)), now: now),
        'hace 5 min',
      );
      expect(
        Formatters.relative(now.subtract(const Duration(hours: 3)), now: now),
        'hace 3 h',
      );
    });
  });

  test('groupByDay agrupa conservando el orden', () {
    final dates = [
      DateTime(2026, 10, 3, 12),
      DateTime(2026, 10, 3, 9),
      DateTime(2026, 10, 2, 20),
      DateTime(2026, 9, 28),
    ];

    final groups = groupByDay(dates, dateOf: (d) => d, now: now);

    expect(groups.map((g) => g.$1), ['Hoy', 'Ayer', '28 sep']);
    expect(groups.first.$2, hasLength(2));
  });
}
