/// Formateo de dinero (USD) y fechas para es-EC, sin dependencias externas.
abstract final class Formatters {
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static final _amountInput = RegExp(r'^(\d{1,7})(?:[.,](\d{0,2}))?$');

  /// `128430` (centavos) → `$1.284,30`. Formato es-EC (CLDR): punto para
  /// miles y coma para decimales; Ecuador está dolarizado.
  static String money(int amountMinor) {
    final negative = amountMinor < 0;
    final abs = amountMinor.abs();
    final dollars = (abs ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final cents = (abs % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}\$$dollars,$cents';
  }

  /// Monto escrito por el usuario (`12`, `12,5`, `12.50`) → centavos.
  /// Devuelve `null` si el texto no es un monto válido.
  static int? parseAmount(String text) {
    final match = _amountInput.firstMatch(text.trim());
    if (match == null) return null;
    final cents = (match.group(2) ?? '').padRight(2, '0');
    return int.parse(match.group(1)!) * 100 + int.parse(cents);
  }

  /// Monto con signo explícito para movimientos: `+$1.800,00`, `-$45,20`.
  static String signedMoney(int amountMinor) =>
      amountMinor >= 0 ? '+${money(amountMinor)}' : money(amountMinor);

  /// Encabezado de grupo: `Hoy`, `Ayer`, `28 sep` o `28 sep 2025`.
  static String dayLabel(DateTime date, {required DateTime now}) {
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    final base = '${local.day} ${_months[local.month - 1]}';
    return local.year == now.year ? base : '$base ${local.year}';
  }

  /// `14:05`
  static String time(DateTime date) {
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  /// Antigüedad de un dato: `hace un momento`, `hace 5 min`, `hace 2 h`.
  static String relative(DateTime date, {required DateTime now}) {
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return 'el ${dayLabel(date, now: now)}';
  }
}

/// Agrupa movimientos (ya ordenados del más reciente al más antiguo) por día
/// local, conservando el orden.
List<(String label, List<T> items)> groupByDay<T>(
  List<T> items, {
  required DateTime Function(T item) dateOf,
  required DateTime now,
}) {
  final groups = <(String, List<T>)>[];
  for (final item in items) {
    final label = Formatters.dayLabel(dateOf(item), now: now);
    if (groups.isNotEmpty && groups.last.$1 == label) {
      groups.last.$2.add(item);
    } else {
      groups.add((label, [item]));
    }
  }
  return groups;
}
