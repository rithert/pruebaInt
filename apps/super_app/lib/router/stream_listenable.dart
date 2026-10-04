import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapta un `Stream` (p. ej. el de un Cubit) a `Listenable`, que es lo que
/// GoRouter usa para reevaluar `redirect` cuando cambia el estado.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
