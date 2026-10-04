import 'dart:async';
import 'dart:developer' as developer;

import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Inicializa Firebase si el build trae `google-services.json`. Si no (un
/// clon del repo sin credenciales), devuelve `false` y la app funciona sin
/// push ni telemetría remota.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on Object catch (error) {
    developer.log('Firebase no disponible: $error', name: 'bootstrap');
    return false;
  }
}

/// Telemetría de producción: eventos de producto en Analytics y errores con
/// su rastro (breadcrumbs) en Crashlytics. Nunca datos personales.
class FirebaseTelemetry implements Telemetry {
  FirebaseTelemetry({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
  }) : _analytics = analytics ?? FirebaseAnalytics.instance,
       _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    // Analytics solo acepta textos o números como parámetros.
    final parameters = <String, Object>{
      for (final entry in params.entries)
        if (entry.value != null)
          entry.key: entry.value is num
              ? entry.value!
              : entry.value.toString().substring(
                  0,
                  entry.value.toString().length.clamp(0, 100),
                ),
    };
    unawaited(_analytics.logEvent(name: name, parameters: parameters));
  }

  @override
  void breadcrumb(String message, {Map<String, Object?> data = const {}}) {
    unawaited(_crashlytics.log('$message $data'));
  }

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    unawaited(
      _crashlytics.recordError(error, stackTrace, reason: reason, fatal: fatal),
    );
  }

  @override
  void setUserId(String? userId) {
    unawaited(_crashlytics.setUserIdentifier(userId ?? ''));
    unawaited(_analytics.setUserId(id: userId));
  }
}
