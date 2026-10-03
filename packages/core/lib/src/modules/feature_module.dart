import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Contrato que implementa cada dominio (auth, cuentas, home…).
///
/// El shell solo conoce esta interfaz: registra las dependencias de cada
/// módulo y monta sus rutas. Así un equipo puede evolucionar su módulo sin
/// tocar el shell ni los demás dominios.
abstract interface class FeatureModule {
  /// Nombre estable del módulo (telemetría, feature flags).
  String get name;

  /// Registra repositorios, casos de uso y cubits del módulo.
  void registerDependencies(GetIt di);

  /// Rutas que aporta el módulo al router de la app.
  List<RouteBase> routes(GetIt di);
}
