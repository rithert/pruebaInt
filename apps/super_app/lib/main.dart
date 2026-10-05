import 'package:flutter/material.dart';

import 'bootstrap/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapped = await bootstrap();
  runApp(bootstrapped.app);
}
