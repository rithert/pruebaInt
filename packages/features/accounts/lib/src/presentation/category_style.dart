import 'package:flutter/material.dart';

/// Etiqueta e ícono de cada categoría del BFF.
abstract final class CategoryStyle {
  static const _styles = <String, (String, IconData)>{
    'groceries': ('Mercado', Icons.shopping_cart_outlined),
    'restaurants': ('Restaurantes', Icons.restaurant_outlined),
    'transport': ('Transporte', Icons.directions_bus_outlined),
    'entertainment': ('Entretenimiento', Icons.movie_outlined),
    'health': ('Salud', Icons.local_pharmacy_outlined),
    'shopping': ('Compras', Icons.shopping_bag_outlined),
    'utilities': ('Servicios', Icons.bolt_outlined),
    'income': ('Ingresos', Icons.payments_outlined),
    'transfer': ('Transferencias', Icons.swap_horiz),
    'savings': ('Ahorro', Icons.savings_outlined),
    'investment': ('Inversión', Icons.trending_up),
    'returns': ('Rendimientos', Icons.show_chart),
    'sales': ('Ventas', Icons.storefront_outlined),
    'suppliers': ('Proveedores', Icons.local_shipping_outlined),
  };

  /// Filtros que se ofrecen en la lista de movimientos.
  static const filters = ['income', 'groceries', 'restaurants', 'transfer'];

  static String label(String category) => _styles[category]?.$1 ?? 'Otros';

  static IconData icon(String category) =>
      _styles[category]?.$2 ?? Icons.receipt_long_outlined;
}
