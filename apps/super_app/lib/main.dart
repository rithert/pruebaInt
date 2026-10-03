import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SuperApp(environment: AppEnvironment.fromDefines()));
}
