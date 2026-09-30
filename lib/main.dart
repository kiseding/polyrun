import 'package:flutter/widgets.dart';

import 'src/controller.dart';
import 'src/ui/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(PolyRunApp(controller: controller));
  controller.bootstrap();
}
