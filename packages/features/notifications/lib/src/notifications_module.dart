import 'package:core/core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'push_service.dart';

class NotificationsModule implements FeatureModule {
  /// [firebaseReady] lo decide el shell al arrancar: sin configuración de
  /// Firebase se registra [DisabledPushService] y la app funciona igual.
  NotificationsModule({required this.firebaseReady});

  final bool firebaseReady;

  @override
  String get name => 'notifications';

  @override
  void registerDependencies(GetIt di) {
    di.registerLazySingleton<PushService>(
      () => firebaseReady
          ? FcmPushService(
              messaging: FirebaseMessaging.instance,
              api: di<ApiClient>(),
              telemetry: di<Telemetry>(),
            )
          : const DisabledPushService(),
    );
  }

  @override
  List<RouteBase> routes(GetIt di) => const [];
}
