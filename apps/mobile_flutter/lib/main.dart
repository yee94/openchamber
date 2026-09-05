import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/app_controller.dart';
import 'data/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(store: PlatformSecureStore());
  runApp(OpenChamberApp(controller: controller));
}
