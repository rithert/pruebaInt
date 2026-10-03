import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de conectividad del dispositivo.
///
/// Ojo: "conectado a una red" no garantiza llegar al BFF (portal cautivo,
/// servidor caído). Por eso la UI combina esta señal con el resultado real
/// de las peticiones, y nunca bloquea una acción solo por este valor.
abstract interface class ConnectivityMonitor {
  Future<bool> get isOnline;
  Stream<bool> get onStatusChange;
}

class PlusConnectivityMonitor implements ConnectivityMonitor {
  PlusConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
