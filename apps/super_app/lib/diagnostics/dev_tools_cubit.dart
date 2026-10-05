import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fallas que el panel puede inyectar en un servicio del BFF.
enum FaultKind {
  down('Caído'),
  slow('Lento (3 s)'),
  errors('Errores 50%');

  const FaultKind(this.label);

  final String label;
}

/// Servicios del BFF que se pueden degradar desde el panel.
const demoServices = <String, String>{
  'accounts': 'Cuentas',
  'experience': 'Experiencia (home)',
  'transfers': 'Transferencias',
  'mini_apps': 'Mini apps',
};

/// Kill switches de la experiencia.
const demoFlags = <String, String>{
  'insights': 'Insights personalizados',
  'promotions': 'Promociones',
  'miniApps': 'Mini apps',
};

class DevToolsState extends Equatable {
  const DevToolsState({
    this.loading = true,
    this.chaos = const {},
    this.flags = const {},
    this.message,
  });

  final bool loading;

  /// servicio → { down, latencyMs, errorRate }.
  final Map<String, Map<String, Object?>> chaos;
  final Map<String, bool> flags;

  /// Resultado de la última acción (se anuncia al lector de pantalla).
  final String? message;

  bool isOn(String service, FaultKind kind) {
    final fault = chaos[service];
    if (fault == null) return false;
    return switch (kind) {
      FaultKind.down => fault['down'] == true,
      FaultKind.slow => ((fault['latencyMs'] as num?) ?? 0) > 0,
      FaultKind.errors => ((fault['errorRate'] as num?) ?? 0) > 0,
    };
  }

  DevToolsState copyWith({
    bool? loading,
    Map<String, Map<String, Object?>>? chaos,
    Map<String, bool>? flags,
    String? message,
  }) => DevToolsState(
    loading: loading ?? this.loading,
    chaos: chaos ?? this.chaos,
    flags: flags ?? this.flags,
    message: message,
  );

  @override
  List<Object?> get props => [loading, chaos.toString(), flags, message];
}

/// Panel de demo: inyecta fallas en el BFF y cambia flags en caliente para
/// mostrar en vivo cómo responde la app. Solo existe en builds de desarrollo.
class DevToolsCubit extends Cubit<DevToolsState> {
  DevToolsCubit({
    required this._api,
    required this._adminKey,
    required this._customerEmail,
  }) : super(const DevToolsState());

  final ApiClient _api;
  final String _adminKey;
  final String? Function() _customerEmail;

  Map<String, String> get _headers => {'x-admin-key': _adminKey};

  /// Las llamadas del panel no se reintentan: deben reflejar lo que pasa.
  static const _extra = {RetryInterceptor.disableKey: true};

  Future<void> load() async {
    final chaos = await _api.get(
      '/admin/chaos',
      decode: _decodeChaos,
      extra: _extra,
      headers: _headers,
    );
    final flags = await _api.get(
      '/admin/flags',
      decode: _decodeFlags,
      extra: _extra,
      headers: _headers,
    );
    emit(
      DevToolsState(
        loading: false,
        chaos: chaos.valueOrNull ?? const {},
        flags: flags.valueOrNull ?? const {},
        message: chaos is Failure || flags is Failure
            ? 'No se pudo leer el estado del servidor.'
            : null,
      ),
    );
  }

  Future<void> toggleFault(String service, FaultKind kind, bool on) async {
    final fault = switch (kind) {
      FaultKind.down => {'down': on},
      FaultKind.slow => {'latencyMs': on ? 3000 : 0},
      FaultKind.errors => {'errorRate': on ? 0.5 : 0},
    };
    final result = await _api.put(
      '/admin/chaos',
      body: {
        'enabled': true,
        'services': {service: fault},
      },
      decode: _decodeChaos,
      headers: _headers,
      extra: _extra,
    );
    _apply(
      result,
      (chaos) => state.copyWith(
        chaos: chaos,
        message:
            '${demoServices[service]}: ${kind.label} '
            '${on ? 'activado' : 'desactivado'}',
      ),
    );
  }

  Future<void> resetChaos() async {
    final result = await _api.delete(
      '/admin/chaos',
      decode: _decodeChaos,
      headers: _headers,
      extra: _extra,
    );
    _apply(
      result,
      (chaos) => state.copyWith(chaos: chaos, message: 'Fallas desactivadas'),
    );
  }

  Future<void> setFlag(String flag, bool value) async {
    final result = await _api.put(
      '/admin/flags',
      body: {flag: value},
      decode: _decodeFlags,
      headers: _headers,
      extra: _extra,
    );
    _apply(
      result,
      (flags) => state.copyWith(
        flags: flags,
        message:
            '${demoFlags[flag]} ${value ? 'activado' : 'desactivado'}. '
            'Desliza hacia abajo en Inicio para verlo.',
      ),
    );
  }

  /// Genera un movimiento real para el cliente actual → llega un push.
  Future<void> generateMovement() async {
    final email = _customerEmail();
    if (email == null) {
      emit(state.copyWith(message: 'Inicia sesión para generar movimientos.'));
      return;
    }
    final result = await _api.post(
      '/admin/activity/tick',
      body: {'email': email},
      decode: (_) {},
      headers: _headers,
      extra: _extra,
    );
    emit(
      state.copyWith(
        message: result is Success
            ? 'Movimiento generado: en segundos llega la notificación.'
            : 'No se pudo generar el movimiento.',
      ),
    );
  }

  void _apply<T>(Result<T> result, DevToolsState Function(T value) onSuccess) {
    emit(switch (result) {
      Success(:final value) => onSuccess(value),
      Failure(:final failure) => state.copyWith(message: failure.message),
    });
  }

  static Map<String, Map<String, Object?>> _decodeChaos(Object? json) {
    final services =
        (json! as Map<String, Object?>)['services']! as Map<String, Object?>;
    return {
      for (final entry in services.entries)
        entry.key: entry.value! as Map<String, Object?>,
    };
  }

  static Map<String, bool> _decodeFlags(Object? json) => {
    for (final entry in (json! as Map<String, Object?>).entries)
      entry.key: entry.value == true,
  };
}
